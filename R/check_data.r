#' Check primary keys are unique
#'
#' @param dt a data.table, for which to check the primary key values.
#' @param colnames a character vector, giving names of columns in the primary
#'   key.
#'
#' @return NULL, if no duplicates found.
#' @export
check_primary_keys_unique <- function(
  dt,
  colnames
) {
  if (length(colnames) == 0)
    stop2("colnames cannot be length zero")
  stop_if_nonempty(
    setdiff(colnames, colnames(dt)),
    "columns not in dt"
  )
  dup <- duplicated(dt, by = colnames)
  stop_if_nonempty(
    unique(dt[dup, ..colnames]),
    "there are duplicated primary keys"
  )
}

#' Check foreign key values are in reference columns
#'
#' @param dt a data.table, for which to check foreign key values.
#' @param ref a data.table, which includes the reference columns to check
#'   against.
#' @param keys a character vector, giving names of foreign key columns in
#'   \code{dt}.
#' @param ref_keys a character vector, giving names of reference columns in
#'   \code{ref}. These should be in the same order as the foreign key columns
#'   they are references for. Defaults to \code{keys}.
#' @param optional a logical, or logical vector, indicating whether foreign key
#'   values can be missing. Note that this is different from the reference
#'   columns being nullable. The length must be one, or equal to the length of
#'   \code{keys}. If length one, the single logical is applied to all keys.
#'   Defaults to FALSE.
#'
#' @return NULL, if no reference errors found.
#' @export
check_foreign_keys <- function(
  dt,
  ref,
  keys,
  ref_keys = keys,
  optional = FALSE
) {
  if (length(keys) == 0)
    stop2("require at least one key")
  if (length(keys) != length(ref_keys))
    stop2("keys and ref_keys must be same length")
  if (length(optional) == 1)
    optional <- rep(optional, length(keys))
  if (length(optional) != length(keys))
    stop2("optional must be length one or same length as keys")
  stop_if_nonempty(
    setdiff(keys, colnames(dt)),
    "foreign key columns not found in dt"
  )
  stop_if_nonempty(
    setdiff(ref_keys, colnames(ref)),
    "reference key columns not found in ref"
  )
  value_miss <- stats::setNames(
    Map(
      function(key, ref_key, optional) {
        setdiff(
          dt[[key]],
          c(
            ref[[ref_key]],
            if (optional) NA
          )
        )
      },
      keys,
      ref_keys,
      optional
    ),
    keys
  )
  stop_if_nonempty(
    remove_empty(value_miss),
    "foreign key values not found in reference columns"
  )
}

#' Check for missing entries in non-nullable columns
#'
#' @param dt a data.table, for which to check for missing entries.
#' @param optional a character vector, containing names of nullable columns in
#'   \code{dt}. These columns are not checked.
#'
#' @return NULL, if no missing non-nullable entries are found.
#' @export
check_no_required_values_missing <- function(
  dt,
  optional = character()
) {
  missing <- lapply(dt[, -..optional], function(x) which(is.na(x)))
  stop_if_nonempty(
    remove_empty(missing),
    "there are missing required values in the following rows"
  )
}

#' Check columns have expected types
#'
#' @param dt a data.table, for which all the column types are checked.
#' @param types a named character vector, with values equal to the expected
#'   types, and names equal to the column names.
#' @param inherit a logical, or logical vector, indicating whether the columns
#'   are checked for inheritance from the expected type. If not, the column's
#'   first class is check for being equal to the expected type. Should have the
#'   same order as \code{types}.
#'
#' @return NULL, if all column types are as expected.
#' @export
check_column_types <- function(
  dt,
  types,
  inherit = FALSE
) {
  diffs <- distinct(colnames(dt), names(types))
  stop_if_nonempty(diffs[[1]], "missing column types")
  stop_if_nonempty(diffs[[2]], "types given for absent columns")
  if (length(inherit) == 1)
    inherit <- rep(inherit, length(types))
  if (length(inherit) != length(types))
    stop2("inherit must be length one or same length as types")
  inherit <- inherit[match(names(types), colnames(dt))]
  types <- types[match(names(types), colnames(dt))]
  actual_types <-  Map(
    function(x, inherit) {
      if (!inherit)
        class(x)[1]
      else
        class(x)
    },
    dt,
    inherit
  )
  type_correct <- mapply(is.element, types, actual_types)
  if (any(!type_correct)) {
    errors <- paste0(
      names(types[!type_correct]),
      ": expected ", types[!type_correct],
      ", observed ",
      vapply(actual_types[!type_correct], toString, character(1)),
      collapse = "\n"
    )
    stop2(paste("unexpected column types", errors, sep = ":\n"))
  }
}

#' Check table entries satisfy given constraint
#'
#' @param dt a data.table, on which to check the constraint.
#' @param expr an expression, which will be evaluated to check the constraint.
#'   Columns in the table can be referred to by name.
#' @param by an option character vector, giving columns over which to group. The
#'   constraint is checked for each group.
#'
#' @return NULL, if the constraint is always satisfied.
#' @export
check_table_constraint <- function(
  dt,
  expr,
  by = NULL
) {
  if (is.null(by)) {
    results <- tryCatch(
      dt[, eval(expr)],
      error = function(e) stop2("constraint evaluation threw an error, check that you're not using variables defined outside of the table")
    )
    if (!is.logical(results) || length(results) != nrow(dt))
      stop2("expression result is not logical with length equal to table entry count")
    invalid <- dt[is.na(results) | results == FALSE]
    stop_if_nonempty(
      invalid,
      paste("table has entries that violate constraint", toString(expr))
    )
  }else{
    results <- tryCatch(
      dt[, .(.eval = eval(expr)), by = by],
      error = function(e) stop2("constraint evaluation threw an error, check that you're not using variables defined outside of the table")
    )
    if (
      !is.logical(results[[".eval"]]) ||
      any(results[, .(.count = .N), by = by] != dt[, .(.count = .N), by = by])
    )
      stop2("expression result is not logical with length equal to group entry count")
    invalid <- dt[results[is.na(.eval) | .eval == FALSE, -c(".eval")], on = by]
    stop_if_nonempty(
      invalid,
      paste("table has entries that violate constraint", toString(expr))
    )
  }
}

#' Check numeric/date start/end interval columns make contiguous interval
#'
#' @param dt a data.table, from which to check the range columns.
#' @param start_column a character, giving the name of the interval start point
#'   column.
#' @param end_column a character, giving the name of the interval end point
#'   column.
#' @param spacing a numeric or integer vector, giving the expected gap between
#'   an interval end and the next interval's start.
#' @param by a character vector, giving names of columns to group over. Defaults
#'   to NULL, for no grouping.
#'
#' @return NULL, if the intervals are contiguous.
#' @export
check_range_contiguous <- function(
  dt,
  start_column,
  end_column,
  spacing,
  by = NULL
) {
  if (
    !is_number_or_date(dt[[start_column]]) ||
    !is_number_or_date(dt[[end_column]])
  )
    stop2("range columns should contain numbers or dates")
  if (
    dt[
      ,
      .(check = any(vapply(.SD, is.unsorted, logical(1)))),
      .SDcols = c(start_column, end_column),
      by = by
    ][, any(check)]
  )
    stop2("range columns are not sorted")
  intervals_dt <- dt[
    ,
    Map(function(x, y) x[-y], .SD, c(.N, 1)),
    .SDcols = c(end_column, start_column),
    by = by
  ][
    ,
    transition := paste(end, start, sep = " -> ")
  ]
  errors <- intervals_dt[end + spacing != start, -c("start", "end")]
  stop_if_nonempty(
    errors,
    paste("ranges are not contiguous with spacing", spacing)
  )
}

check_column_relation <- function(
  dt1,
  dt2,
  column1,
  column2,
  fun,
  by = NULL
) {
  if (is.null(by) && !identical(dt1[[column1]], fun(dt2[[column2]])))
    stop2("first column not function of second column")
  if (!is.null(by)) {
    test1 <- setorderv(
      dt1[
        , c(..by, ..column1)
      ],
      by
    )
    test2 <- setorderv(
      dt2[
        , lapply(.SD, fun), .SDcols = column2, by = by
      ][
        , setnames(.SD, c(by, column1))
      ],
      by
    )
    if (!identical(test1, test2))
      stop2("first column not function of second column")
  }
}

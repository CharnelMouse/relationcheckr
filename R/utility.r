remove_empty <- function(
  lst
) {
  lst[vapply(lst, length, integer(1)) > 0]
}

toString.list <- function(lst, ...) {
  paste(
    names(lst),
    vapply(lst, toString, character(1)),
    sep = ": ",
    collapse = "\n"
  )
}

toString.data.frame <- function(dt, ...) {
  paste(
    apply(dt, 1L, toString.list),
    collapse = "\n\n"
  )
}

stop2 <- function(
  ...
) {
  stop(..., call. = FALSE)
}

stop_if_nonempty <- function(
  x,
  err
) {
  UseMethod("stop_if_nonempty")
}

stop_if_nonempty.default <- function(
  x,
  err
) {
  if (length(x) > 0)
    stop2(paste(err, toString(x), sep = ": "))
}

stop_if_nonempty.list <- function(
  x,
  err
) {
  if (length(x) > 0)
    stop2(paste(err, toString.list(x), sep = ":\n"))
}

stop_if_nonempty.data.frame <- function(
  x,
  err
) {
  if (nrow(x) > 0)
    stop2(paste(err, toString.data.frame(x), sep = ":\n"))
}

distinct <- function(
  x,
  y
) {
  list(setdiff(x, y), setdiff(y, x))
}

is_number_or_date <- function(
  x
) {
  is.numeric(x) || is.integer(x) || is(x, "Date")
}

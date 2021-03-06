#' @importFrom magrittr %>%
#' @importFrom magrittr extract
#' @importFrom dplyr mutate
#' @importFrom dplyr mutate_at
#' @importFrom dplyr mutate_all
#' @importFrom dplyr pull
#' @importFrom dplyr select
#' @importFrom dplyr rename
#' @importFrom dplyr as_data_frame
#' @importFrom dplyr bind_rows
#' @importFrom dplyr group_by
#' @importFrom dplyr is_grouped_df
#' @importFrom dplyr ungroup
#' @importFrom dplyr do
#' @importFrom dplyr filter
#' @importFrom dplyr tibble
#' @importFrom dplyr everything
#' @importFrom dplyr left_join
#' @importFrom purrr map
#' @importFrom broom tidy
#' @importFrom stats t.test
#' @importFrom rlang sym
#' @importFrom rlang !!
#' @importFrom rlang :=
#' @importFrom rlang set_attrs
#' @importFrom rlang quos
#' @importFrom rlang quo_name
#' @importFrom tibble add_column
#' @importFrom tibble as_tibble
#' @importFrom tidyr spread
#' @importFrom tidyr gather



# Extract variables used in a formula
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.extract_formula_variables <- function(formula){
  outcome <- deparse(formula[[2]])
  group <- attr(stats::terms(formula), "term.labels")
  list(outcome = outcome, group = group)
}

# Convert a group column into a factor if this is not already the case
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# group.col column name containing groups
# ref.group: optional reference group
# ToothGrowth %>% .as_factor("dose", ref.group = "0.5") %>% pull("dose")
.as_factor <- function (data, group.col, ref.group = NULL){
  group.values <- data %>% pull(group.col)
  if(!is.factor(group.values))
    group.values <- as.factor(group.values)
  if(!is.null(ref.group))
    group.values <- stats::relevel(group.values, ref.group)
  data %>% mutate(!!group.col := group.values)
}



# Guess p-value column name from a statistical test output
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.guess_pvalue_column <- function(data){
  matches <- dplyr::matches
  common.p.cols <- "^p$|^pval$|^pvalue$|^p\\.val$|^p\\.value$"
  p.col <- data %>%
    select(matches(common.p.cols)) %>%
    colnames()
  if(.is_empty(p.col))
    stop("Can't guess the p value column from the input data. Specify the p.col argument")
  p.col
}

# Generate all possible pairs of a factor levels
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# if ref.group is specified, then all possible pairs,
# against reference group, are generated
.possible_pairs <- function(group.levels, ref.group = NULL){

  # Ref group should be always the first group
  if(!is.null(ref.group))
    group.levels <- c(ref.group,  group.levels) %>% unique()
  # Generate possible pairs
  possible.pairs <- utils::combn(group.levels, 2) %>%
    as.data.frame()
  mate1 <- possible.pairs[1,]
  # select only comparisons against ref.group (if specified)
  if(!is.null(ref.group))
    possible.pairs <- possible.pairs %>%
    select(which(mate1 == ref.group))

  possible.pairs %>% as.list()
}



# Create a tidy statistical output
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Generic function to create a tidy statistical output
as_tidy_stat <- function(x, digits = 2){

  stat.method <- get_stat_method(x)

  estimate <- estimate1 <- estimate2 <- p.value <-
    alternative <- NULL
  res <- x %>%
    tidy() %>%
    mutate(
      p.value = signif(p.value, digits),
      method = stat.method
    ) %>%
    rename(p = p.value)
  res
}

get_stat_method <- function(x){

  if(inherits(x, c("aov", "anova"))){
    return("Anova")
  }
  available.methods <- c(
    "T-test", "Wilcoxon", "Kruskal-Wallis",
    "Pearson", "Spearman", "Kendall"
  )
  used.method <- available.methods %>%
    map(grepl, x$method, ignore.case = TRUE) %>%
    unlist()
  available.methods %>% extract(used.method)
}

# Check if en object is empty
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.is_empty <- function(x){
  length(x) == 0
}

# Check if is a list
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.is_list <- function(x){
  inherits(x, "list")
}

# Returns the levels of a factor variable
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.levels <- function(x){
  if(!is.factor(x)) x <- as.factor(x)
  levels(x)
}

# Additems in a list
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.add_item <- function(.list, ...){
  pms <- list(...)
  for(pms.names in names(pms)){
    .list[[pms.names]] <- pms[[pms.names]]
  }
  .list
}


# First letter uppercase
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
to_uppercase_first_letter <- function(x) {
  substr(x, 1, 1) <- toupper(substr(x, 1, 1))
  x
}


# Data conversion
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

as_matrix <- function(x){

  if(inherits(x, "tbl_df")){
    tibble_to_matrix(x)
  }
  else if(inherits(x, "matrix")){
    x
  }
  else if(is.data.frame(x)){
    if("rowname" %in% colnames(x)){
      x %>%
        tibble::remove_rownames() %>%
        tibble::column_to_rownames("rowname") %>%
        as_matrix()
    }
    else {
      as.matrix(x)
    }
  }
  else{
    as.matrix(x)
  }
}


# Convert a tbl to matrix
tibble_to_matrix <- function(x){
  x <-  as.data.frame(x)
  rownames(x) <- x[, 1]
  x <- x[, -1]
  as.matrix(x)
}

# Convert a matrix to standard data frame
matrix_to_dataframe <- function(x){
  x <- as.data.frame(x, stringsAsFactors = FALSE) %>%
    add_column(rowname = rownames(x), .before = 1)
  rownames(x) <- NULL
  x
}

# Convert a matrix to tibble
matrix_to_tibble <- function(x){
  as_tibble(x, rownames = "rowname")
}

# Replace empty space as na
replace_empty_by <- function(x, replacement = NA){
  x %>% dplyr::mutate_all(
      function(x){x[x==""] <- replacement; x}
      )
}


# Correlation analysis
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

# Stop if not an object of class cor_mat
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++
stop_ifnot_cormat <- function(x){
  if(!inherits(x, "cor_mat")){
    stop("An object of class cor_mat is required")
  }
}

# Subset a correlation matrix, return a tibble
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++
subset_matrix <- function(x, vars, row.vars = vars,
                          col.vars = vars){

  if(inherits(x, c("tbl_df", "data.frame"))){
    . <- NULL
    x %>% as_matrix() %>%
      .[row.vars, col.vars, drop = FALSE] %>%
      as_tibble(rownames = "rowname")
  }
  else if(inherits(x, "matrix")){
    x[row.vars, col.vars, drop = FALSE] %>%
      as_tibble(rownames ="rowname")
  }
  else{
    stop("x should be a data frame or rownames")
  }
}


# Tidy Select
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

# Collect variables provided by users; get selected variables
get_selected_vars <- function(x, ..., vars = NULL){

  if(is_grouped_df(x))
    x <- x %>% dplyr::ungroup()
  dot.vars <- rlang::quos(...)

  if(length(vars) > 0){
    return(vars)
  }
  if (length(dot.vars) == 0) selected <- colnames(x)
  else selected <- tidyselect::vars_select(names(x), !!! dot.vars)
  selected %>% as.character()
}


# Select numeric columns
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
select_numeric_columns <- function(data){
  if(is_grouped_df(data))
    data <- data %>% dplyr::ungroup()
  data %>% dplyr::select_if(is.numeric)
}

# Add a class to an object
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
add_class <- function(x, .class){
  for(.cl in .class){
    if(!inherits(x, .cl))
      x <- structure(x, class = c(class(x), .cl))
  }
  x
}

# Correlation analysis
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

# Check classes
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
.is_cor_mat <- function(x){
  inherits(x, "cor_mat")
}

.is_cor_test <- function(x){
  inherits(x, "cor_test")
}

# Convert a cor_mat_tri to numeric data
as_numeric_triangle <- function(x){
  rrowname <- x %>% pull(1)
  res <- x %>%
    replace_empty_by(NA) %>%
    select(-1) %>%
    mutate_all(as.numeric) %>%
    add_column(rowname = rrowname, .before = 1)
  res
}


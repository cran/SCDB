## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

# Set a flag to determine if the vignette should be run in simple context (vignettes)
# or in an extended context (pkgdown)
simple_rendering <- !pkgdown::in_pkgdown()

# NOTE:
# To re-run the benchmarks, run the "benchmark" workflow on GitHub

## -----------------------------------------------------------------------------
library(magrittr)

## ----benchmark context, results = "asis", include = FALSE---------------------
if (simple_rendering) {
  cat(
    "The results of the benchmark are shown graphically below",
    "(mean and standard deviation), where measure the",
    "performance of `SCDB`."
  )
} else {
  cat(
    "The results of the benchmark are shown graphically below",
    "(mean and standard deviation), where we compare the",
    "current development version of `SCDB` with the current CRAN version."
  )
}

## ----benchmark_preprocessing, echo = FALSE, eval = requireNamespace("here")----
benchmark_location <- c(
  system.file("extdata", "benchmarks.rds", package = "SCDB"),
  here::here("inst", "extdata", "benchmarks.rds")
) %>%
  purrr::discard(~ identical(., "")) %>%
  purrr::pluck(1)

benchmarks <- readRDS(benchmark_location) %>%
  dplyr::mutate("version" = as.character(.data$version))

# Determine if the SHA is on main
sha <- benchmarks %>%
  dplyr::distinct(.data$version) %>%
  dplyr::filter(!startsWith(.data$version, "SCDB"), .data$version != "main") %>%
  dplyr::pull("version")

# Check local git history
on_main <- tryCatch({
  system(glue::glue("git branch main --contains {sha}"), intern = TRUE) %>%
    stringr::str_detect(stringr::fixed("main")) %>%
    isTRUE()
}, warning = function(w) {
  # If on GitHub, git is not installed and we assume TRUE.
  # This will render the vignette as it will look once merged onto main.
  return(identical(Sys.getenv("CI"), "true"))
})

# In the simple context we use the newest benchmark (version = sha)
# This benchmark is then labelled with the newest version number of SCDB
if (simple_rendering) {
  benchmarks <- benchmarks %>%
    dplyr::filter(.data$version == !!sha) %>%
    dplyr::mutate("version" = paste0("SCDB v", packageVersion("SCDB")))
} else if (on_main) {
  # If the SHA has been merged, use as the "main" version and remove the other,
  # older, main version
  benchmarks <- benchmarks %>%
    dplyr::filter(.data$version != "main") %>%
    dplyr::mutate(
      "version" = dplyr::if_else(.data$version == sha, "development", .data$version)
    )
}

# Mean and standard deviation (see ggplot2::mean_se())
mean_sd <- function(x) {
  mu <- mean(x)
  sd <- sd(x)
  data.frame(y = mu, ymin = mu - sd, ymax = mu + sd)
}

## ----benchmark_1, echo = FALSE, eval = requireNamespace("here")---------------
# Use data for benchmark 1
benchmark_1 <- benchmarks %>%
  dplyr::filter(
    !stringr::str_ends(.data$benchmark_function, stringr::fixed("complexity"))
  )

# Insert newline into database name to improve rendering of figures
labeller <- ggplot2::as_labeller(
  function(l) stringr::str_replace_all(l, stringr::fixed(" v"), "\nv")
)

# Apply "dodging" to sub-groups to show graphically
dodge <- ggplot2::position_dodge(width = 0.6)

g <- ggplot2::ggplot(
  benchmark_1,
  ggplot2::aes(x = version, y = time / 1e9, color = database)
) +
  ggplot2::stat_summary(
    fun.data = mean_sd,
    geom = "pointrange",
    size = 0.5,
    linewidth = 1,
    position = dodge
  ) +
  ggplot2::scale_x_discrete(guide = ggplot2::guide_axis(n.dodge = 2)) +
  ggplot2::labs(x = "Codebase version", y = "Time (s)") +
  ggplot2::theme(legend.position = "bottom")


if (simple_rendering) {
  # Reduce font size for simple version
  g <- g + ggplot2::theme(text = ggplot2::element_text(size = 8))

  # Make the legend two rows
  g <- g + ggplot2::guides(
    color = ggplot2::guide_legend(title = "", nrow = 2, byrow = TRUE)
  )

} else {
  # Add facets to extended rendering
  g <- g +
    ggplot2::facet_grid(
      rows = ggplot2::vars(benchmark_function),
      cols = ggplot2::vars(database),
      labeller = labeller
    )
}

g

## ----benchmark_2, echo = FALSE, eval = requireNamespace("here")---------------
# Use data for benchmark 2
benchmark_2 <- benchmarks %>%
  dplyr::filter(
    stringr::str_ends(
      .data$benchmark_function,
      stringr::fixed("complexity")
    )
  ) %>%
  dplyr::mutate(
    "benchmark_function" = stringr::str_remove_all(
      benchmark_function,
      stringr::fixed("- complexity")
    )
  )


# Apply "dodging" to sub-groups to show graphically
dodge <- ggplot2::position_dodge(width = 0.6)

# Set aesthetics for simple and extended versions
if (simple_rendering) {
  aes <- ggplot2::aes(x = n * nrow(iris) / 1e3, y = time / 1e9, color = database)
} else {
  aes <- ggplot2::aes(x = n * nrow(iris) / 1e3, y = time / 1e9, color = version)
}

g <- ggplot2::ggplot(
  benchmark_2,
  aes
) +
  ggplot2::stat_summary(
    fun.data = mean_sd,
    geom = "pointrange",
    size = 0.5, linewidth = 1,
    position = dodge
  ) +
  ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE, linetype = 3) +
  ggplot2::labs(
    x = "Data size (1,000 rows)",
    y = "Time (s)",
    color = "Codebase version"
  ) +
  ggplot2::theme(panel.spacing = grid::unit(1, "lines"), legend.position = "bottom")


if (simple_rendering) {
  # Reduce font size for simple version
  g <- g + ggplot2::theme(text = ggplot2::element_text(size = 8))

  # Make the legend two rows
  g <- g + ggplot2::guides(
    color = ggplot2::guide_legend(title = "", nrow = 2, byrow = TRUE)
  )

} else {
  # Add facets to extended rendering
  g <- g +
    ggplot2::facet_grid(
      rows = ggplot2::vars(benchmark_function),
      cols = ggplot2::vars(database),
      labeller = labeller
    )
}

g


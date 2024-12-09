#' @noRd
path_to_data_structure <- function() {
    system.file("extdata/content_mapping_AMU.xlsx", package = "AMView")
}

#' @noRd
path_to_markdown <- function(filename) {
    system.file(file.path("markdown", filename), package = "AMView")
}

#' Get ATC codes dataset
#' @noRd
get_atc <- function(include_product = FALSE) {
    dt <- data.table::fread(system.file("extdata/atc.csv", package = "AMView"))

    if (isFALSE(include_product))
        dt <- dt[, -"handelsvarakod"]

    unique(dt)
}

#' Get AMU dataset
#' @noRd
get_amu <- function() {
    dt <- data.table::fread(
        system.file("extdata/amu.csv", package = "AMView"), encoding = "UTF-8"
    )
    atc <- get_atc()

    data.table::merge.data.table(
        dt,
        atc,
        by.x = "ATCcode",
        by.y = "atc_code",
        all.x = TRUE
    )
}

#' A named list of the variables that go into the common data structure and
#' their types.
#'
#' The names of the list elements returned are the variable names defined in
#' the common data structure, and the values can be one of three things:
#' * Unnamed vector: represents the legal values that that variable can have;
#' * Empty vector of a given type: defines the legal type of that variable (
#'   but the actual value is not restricted);
#' * Named numeric vector with values between 0 and 1: the names represent the
#'   legal values and the numeric value represent the probability with which
#'   the values should appear when generating artificial data.
#'
#' Note that the legal values given here are  tailored to be used for
#' generating artificial data using the \code{amu_dummy_data} function, and to
#' loosely mimic the Swedish cattle sector. The pool of legal values
#' specified here is therefore not universal; see the file  under
#' \code{inst/extdata/content_mapping_AMU.xlsx} for the full specification of
#' the common data structure.
#'
#' @param varnames if "all" (default), returns all values. Otherwise returns
#' a subset whose names corresponds to the values given.
#' @return a list as described above.
#' @export
am_variables <- function(varnames = "all") {
    vars <- list(
        EntryID = integer(),
        TypeOfEntry = c(
            "Pharmacy sale (prescription)",
            "Pharmacy sale (requisition)",
            "Pharmacy sale (other/unknown)",
            "Journal entry (use by veterinarian)",
            "Journal entry (use by animal owner)",
            "Journal entry (prescription by veterinarian)",
            "Journal entry (other)",
            "Other"
        ),
        IncludeAsUse = TRUE,
        DateTransaction = as.Date(NULL),
        DateTreatment = as.Date(NULL),
        DateOther = as.Date(NULL),
        DateOtherComment = character(),
        Country = "SE",
        NUTS2 = paste0("SE", c(11, 12, 21, 22, 23, 31, 32, 33)),
        NUTS3 = c(
            "SE110" = 0.01,
            "SE121" = 0.03,
            "SE122" = 0.03,
            "SE123" = 0.1,
            "SE124" = 0.1,
            "SE125" = 0.03,
            "SE211" = 0.05,
            "SE212" = 0.03,
            "SE213" = 0.05,
            "SE214" = 0.02,
            "SE221" = 0.05,
            "SE224" = 0.2,
            "SE231" = 0.05,
            "SE232" = 0.1,
            "SE311" = 0.05,
            "SE312" = 0.03,
            "SE313" = 0.02,
            "SE321" = 0.005,
            "SE322" = 0.015,
            "SE331" = 0.025,
            "SE332" = 0.005
        ),
        GeoComment = character(),
        HerdID = character(),
        AnimalSpecies = "Cattle",
        AnimalType = c(
            "Beef cattle" = 0.4,
            "Dairy cattle" = 0.55,
            "Other cattle" = 0.05
        ),
        ProductionType = c("Breeders", "Meat/Fattening", "Milk"),
        Gender = c("Male", "Female", "Unknown"),
        AgeCategory = c("<6 months", "6-24 months", ">24 months"),
        TreatmentPurpose = c("Metaphylactic", "Treatment"),
        Indication = paste("Indication", 1:10),
        Diagnosis = c(
            "Mastitis" = 0.65,
            "Lameness" = 0.12,
            "Obstetrics and reproductive disorder" = 0.09,
            "Other infection" = 0.06,
            "Other" = 0.08
        ),
        AdministrationMethod = c(
            "Injectable products", "Intramammary products", "Oral solutions",
            "Oral pastes", "Oral powders", "Premixes", "Tablets and similar",
            "Intrauterine products", "Topical dermatological products",
            "Topical ophthalmological products", "Topical otology products",
            "Topical nasal products", "Other"
        ),
        TreatedUnit = c("Individual", "Group", "Herd"),
        NumberOfAnimals = integer(),
        MedicalProductName = character(),
        MedicalProductCode = get_atc()$handelsvarakod,
        ATCcode = get_atc()$atc_kod,
        ActiveIngredient = get_atc()$substance,
        ActiveSubstanceKg = numeric()
    )

    if (varnames == "all")
        return(vars)

    vars[[varnames]]
}

#' Generate some random artificial AMU data adhering to the variable rules
#' defined by the function \code{am_variables}. ATC codes are fetched from the
#' "atc.csv" file in this package, whose source is the Swedish Board
#' of Agriculture. The EntryID is merely an index of the row number.
#'
#' NOTE! This function takes quite some time to run for large values of
#' \code{n_rows}.
#'
#' @param n_rows the number of rows in the dataset
#' @param start_date The earliest possible date of transaction
#' @param end_date The latest possible date of transaction.
#' @return a data.frame with the dummy data
#' @export
amu_dummy_data <- function(n_rows, start_date, end_date) {

    # Make sure the input variables are correctly formatted
    start_date <- as.Date(start_date)
    end_date <- as.Date(end_date)
    stopifnot(is.numeric(n_rows), n_rows >= 1, n_rows %% 1 == 0)
    stopifnot(end_date > start_date)

    # Load CSV file with statistics for how much antimicrobials have been used
    # expressed as absolute numbers and proportions per medication and year.
    # Based on official Swedish AMU statistics.
    use_proportions <- data.table::fread(
        system.file("extdata/use_proportions.csv", package = "AMView"),
        dec = ","
    )

    # nolint start

    atc_code <- NULL

    # Load medication ATC code dataset, but only keep those that exist within
    # the use proportions data.
    subgroups <- unique(use_proportions$medication)
    atc <- get_atc(include_product = TRUE)[
        sapply(atc_code, function(x) any(startsWith(x, subgroups)))
    ]

    vars <- am_variables()

    EntryID  <- seq_len(n_rows)
    TypeOfEntry <- sample(vars$TypeOfEntry, n_rows, TRUE)
    IncludeAsUse <- rep(vars$IncludeAsUse, n_rows)
    DateTransaction <- sample(seq(start_date, end_date, "day"), n_rows, TRUE)
    DateTreatment <- as.Date(sapply(seq_len(n_rows), function(i) {
        sample(seq(DateTransaction[i], DateTransaction[i] + 3, "day"), 1, TRUE)
    }))
    DateOther <- as.Date(rep(NA, n_rows))
    DateOtherComment <- rep(NA_character_, n_rows)
    Country <- sample(vars$Country, n_rows, TRUE)
    NUTS3 <- sapply(seq_len(n_rows), function(i) {
        sample(names(vars$NUTS3), size = 1, prob = vars$NUTS3)
    })
    NUTS2 <- sapply(NUTS3, function(x) {
        vars$NUTS2[which(startsWith(x, vars$NUTS2))]
    })
    GeoComment <- rep("Location in Sweden", n_rows)
    HerdID <- paste0(Country, "_", sample(1:250, n_rows, TRUE))
    AnimalSpecies <- sample(vars$AnimalSpecies, n_rows, TRUE)
    AnimalType <- sapply(
        seq_len(n_rows), function(i) {
            sample(names(vars$AnimalType), size = 1, prob = vars$AnimalType)
        }
    )
    ProductionType <- sample(vars$ProductionType, n_rows, TRUE)
    Gender <- sample(vars$Gender, n_rows, TRUE)
    AgeCategory <- sample(vars$AgeCategory, n_rows, TRUE)
    TreatmentPurpose <- sample(vars$TreatmentPurpose, n_rows, TRUE)
    Indication <- sample(vars$Indication, n_rows, TRUE)

    Diagnosis <- factor(
        sapply(
            seq_len(n_rows), function(i) {
                sample(names(vars$Diagnosis), size = 1, prob = vars$Diagnosis)
            }
        ),
        levels = names(vars$Diagnosis)
    )

    AdministrationMethod <- sample(vars$AdministrationMethod, n_rows, TRUE)
    TreatedUnit <- sample(vars$TreatedUnit, n_rows, TRUE)
    NumberOfAnimals <- sapply(seq_len(n_rows), function(i) {
        if (TreatedUnit[i] == "Individual")
            return(1)
        sample(2:250, 1, TRUE)
    })
    product_index <- sample(seq_len(nrow(atc)), n_rows, TRUE)
    MedicalProductName <- rep(NA_character_, n_rows)
    MedicalProductCode <- atc$handelsvarakod[product_index]
    ATCcode <- atc$atc_code[product_index]
    ActiveIngredient <- atc$substance[product_index]
    year <- as.numeric(format(DateTransaction, "%Y"))
    group <- sapply(
        ATCcode, function(x) {
            subgroups[which(startsWith(x, subgroups))]
        }, USE.NAMES = FALSE
    )

    freqs <- as.data.frame(table(list(year = year, medication = group)))
    freqs$year <- as.integer(as.character(freqs$year))
    freqs$medication <- as.character(freqs$medication)

    use_proportions <- merge(
        freqs,
        use_proportions,
        by = c("year", "medication"),
        all.x = TRUE
    )

    use_proportions$substance_share  <- numeric(nrow(use_proportions))

    for (y in unique(use_proportions$year)) {
        i <- use_proportions$year == y
        use_proportions[i, ]$proportion <-
            prop.table(use_proportions[i, ]$proportion)
        use_proportions[i, ]$substance_share <-
            round(sample(9800:10300, 1) * use_proportions[i, ]$proportion)
    }

    ActiveSubstanceKg <-
        unlist(sapply(unique(use_proportions$year), function(y) {

        df <- use_proportions[use_proportions$year == y, ]
        counts <- df$Freq
        substance <- df$substance_share

        buckets <- unlist(mapply(function(n, m) {
            if (m == 0)
                return(rep(0, n))

            b <- stats::runif(n, 0, m)

            b / sum(b) * m
        }, counts, substance, SIMPLIFY = TRUE))
    }))

    data <- data.frame(
        EntryID,
        TypeOfEntry,
        IncludeAsUse,
        DateTransaction,
        DateTreatment,
        DateOther,
        DateOtherComment,
        Country,
        NUTS2,
        NUTS3,
        GeoComment,
        HerdID,
        AnimalSpecies,
        AnimalType,
        ProductionType,
        Gender,
        AgeCategory,
        TreatmentPurpose,
        Indication,
        Diagnosis,
        AdministrationMethod,
        TreatedUnit,
        NumberOfAnimals,
        MedicalProductName,
        MedicalProductCode,
        ATCcode,
        ActiveIngredient,
        ActiveSubstanceKg
    )
    #nolint end

    colnames(data) <- names(vars)

    data <- data[order(data$DateTransaction, data$EntryID), ]

    data$EntryID <- rownames(data) <- seq_len(nrow(data))

    data[data$ActiveSubstanceKg > 0, ]
}


#' Extract spatial data for a given list of European countries
#' @param country_codes official NUTS country codes for the countries to
#'        retrieve data from.
#' @return an \code{sf} object with the desired geospatial data.
#'
#' @export
get_spatial_data <- function(country_codes) {
    countries <- eurostat::get_eurostat_geospatial(
        output_class = "sf",
        nuts_level = "3",
        resolution = "03"
    )

    stopifnot(all(country_codes %in% countries$CNTR_CODE))

    countries[countries$CNTR_CODE %in% country_codes, ]
}

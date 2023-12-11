# AMView - Visualize AMU Data

This dashboard is an RShiny application, developed as an R package, that visualizes antimicrobial use (AMU) data in animals. The application
was developed as part of the [DigiVet](http://www.dcs.gla.ac.uk/~jenright/digivet_website/) project.
This source code will see continued development after the project is condluded; a static project deliverable version of the application is archived at [Zenodo](https://zenodo.org/communities/digivet?q=&l=list&p=1&s=10&sort=newest).

 The package also has functionality to randomly generate artificial to use for app showcasing. The parameters for the data generation are currently set so that the generated data will loosely imitate official AMU statistics from the Swedish cattle sector. The data format follows a common AMU data structure which has been developed within the DigiVet project. An instruction and template for the common data structure can be downloaded within the application, or viewed in this repository under `inst/extdata/Content mapping AMU.xlsx`.

## Installing and running AMView

### Artificial data

If you want to run the app with the pre-loaded artificial data, the easiest installation method is directly through R:

``` r
library(devtools)
install_github("SVA-SE/AMView")
```

You can then run the Shiny app like this:

``` r
AMView::run_app()
```

which should launch a local Shiny server and automatically open a browser window with the app.

### With your own data

Currently, AMView only supports reading data which is "baked into" the R package itself. Therefore, if you want to run the app with your own data you will need to make modifications to the source code. To do so, follow these steps:

1. Clone this repository. Or, if you want to save your modifications, create a fork of this repo and clone that fork.

2. In your local copy, replace the CSV file under `inst/extdata/amu.csv` with one that contains the data you want to visualize. Follow the specification in `inst/extdata/Content mapping AMU.xlsx` to make sure the columns of the CSV are named and formatted correctly.

3. Install the package. The easiest way is to open R in the root of the local repo, and write the following:

    ``` r
    devtools::install_local(force = TRUE)
    ```

4. Run the application in the same way as above:
    ``` r
    AMView::run_app()
    ```
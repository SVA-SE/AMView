# Determine package name and version from DESCRIPTION file
PKG_VERSION=$(shell grep -i ^version DESCRIPTION | cut -d : -d \  -f 2)
PKG_NAME=$(shell grep -i ^package DESCRIPTION | cut -d : -d \  -f 2)

# Name of built package
PKG_TAR=$(PKG_NAME)_$(PKG_VERSION).tar.gz

# Install package
.PHONY: install
install:
	cd .. && R CMD INSTALL $(PKG_NAME)

# Build documentation with roxygen
# 1) Remove old doc
# 2) Generate documentation
.PHONY: roxygen
roxygen:
	rm -f man/*.Rd
	cd .. && Rscript -e "library(roxygen2); roxygenize('$(PKG_NAME)')"

# Build and check package
.PHONY: check
check:
	cd .. && R CMD build $(PKG_NAME)
	cd .. && _R_CHECK_CRAN_INCOMING_=FALSE R CMD check \
          --no-stop-on-test-error --as-cran --run-dontrun $(PKG_TAR)

# Run static code analysis
.PHONY: lintr
lintr:
	Rscript \
          -e "library(lintr)" \
          -e "lint_package(linters = with_defaults(object_name_linter = NULL, \
          object_usage_linter = NULL))"

.PHONY: deploy
deploy:
	Rscript "shinyapps-io/deploy.R"

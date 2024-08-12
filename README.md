About chem_data-feedstock
=========================

Feedstock license: [BSD-3-Clause](https://github.com/phenix-project/phenix-feedstock/blob/main/LICENSE.txt)

Home: https://github.com/cctbx/cctbx_project

Package license: BSD-3-Clause-LBNL AND BSD-3-Clause AND BSL-1.0 AND LGPL-2.0-only AND LGPL-2.1-only AND LGPL-3.0-only AND MIT AND LGPL-2.0-or-later WITH WxWindows-exception-3.1

Summary: The Computational Crystallography Toolbox

Development: https://github.com/cctbx/cctbx_project

Documentation: https://cctbx.github.io/

The Computational Crystallography Toolbox (cctbx) is being developed
as the open source component of the Phenix system. The goal of the
Phenix project is to advance automation of macromolecular structure
determination. Phenix depends on the cctbx, but not vice versa. This
hierarchical approach enforces a clean design as a reusable library.
The cctbx is therefore also useful for small-molecule crystallography
and even general scientific applications.


Current build status
====================


<table><tr><td>All platforms:</td>
    <td>
      <a href="https://dev.azure.com/phenix-release/feedstock-builds/_build/latest?definitionId=7&branchName=main">
        <img src="https://dev.azure.com/phenix-release/feedstock-builds/_apis/build/status/phenix-feedstock?branchName=main">
      </a>
    </td>
  </tr>
</table>

Current release info
====================

| Name | Downloads | Version | Platforms |
| --- | --- | --- | --- |
| [![Conda Recipe](https://img.shields.io/badge/recipe-chem_data-green.svg)](https://anaconda.org/cctbx-dev/chem_data) | [![Conda Downloads](https://img.shields.io/conda/dn/cctbx-dev/chem_data.svg)](https://anaconda.org/cctbx-dev/chem_data) | [![Conda Version](https://img.shields.io/conda/vn/cctbx-dev/chem_data.svg)](https://anaconda.org/cctbx-dev/chem_data) | [![Conda Platforms](https://img.shields.io/conda/pn/cctbx-dev/chem_data.svg)](https://anaconda.org/cctbx-dev/chem_data) |

Installing chem_data
====================

Installing `chem_data` from the `cctbx-dev` channel can be achieved by adding `cctbx-dev` to your channels with:

```
conda config --add channels cctbx-dev
conda config --set channel_priority strict
```

Once the `cctbx-dev` channel has been enabled, `chem_data` can be installed with `conda`:

```
conda install chem_data
```

or with `mamba`:

```
mamba install chem_data
```

It is possible to list all of the versions of `chem_data` available on your platform with `conda`:

```
conda search chem_data --channel cctbx-dev
```

or with `mamba`:

```
mamba search chem_data --channel cctbx-dev
```

Alternatively, `mamba repoquery` may provide more information:

```
# Search all versions available on your platform:
mamba repoquery search chem_data --channel cctbx-dev

# List packages depending on `chem_data`:
mamba repoquery whoneeds chem_data --channel cctbx-dev

# List dependencies of `chem_data`:
mamba repoquery depends chem_data --channel cctbx-dev
```




Updating chem_data-feedstock
============================

If you would like to improve the chem_data recipe or build a new
package version, please fork this repository and submit a PR. Upon submission,
your changes will be run on the appropriate platforms to give the reviewer an
opportunity to confirm that the changes result in a successful build. Once
merged, the recipe will be re-built and uploaded automatically to the
`cctbx-dev` channel, whereupon the built conda packages will be available for
everybody to install and use from the `cctbx-dev` channel.
Note that all branches in the phenix-project/chem_data-feedstock are
immediately built and any created packages are uploaded, so PRs should be based
on branches in forks and branches in the main repository should only be used to
build distinct package versions.

In order to produce a uniquely identifiable distribution:
 * If the version of a package **is not** being increased, please add or increase
   the [``build/number``](https://docs.conda.io/projects/conda-build/en/latest/resources/define-metadata.html#build-number-and-string).
 * If the version of a package **is** being increased, please remember to return
   the [``build/number``](https://docs.conda.io/projects/conda-build/en/latest/resources/define-metadata.html#build-number-and-string)
   back to 0.

Feedstock Maintainers
=====================

* [@bkpoon](https://github.com/bkpoon/)
* [@phyy-nx](https://github.com/phyy-nx/)


About phenix
============

Home: https://github.com/cctbx/cctbx_project

Package license: BSD-3-Clause-LBNL AND BSD-3-Clause AND BSL-1.0 AND LGPL-2.0-only AND LGPL-2.1-only AND LGPL-3.0-only AND MIT AND LGPL-2.0-or-later WITH WxWindows-exception-3.1

Feedstock license: [BSD-3-Clause](https://github.com/phenix-project/phenix-feedstock/blob/master/LICENSE.txt)

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


<table>
    
  <tr>
    <td>Azure</td>
    <td>
      <details>
        <summary>
          <a href="https://dev.azure.com/phenix-project/feedstock-builds/_build/latest?definitionId=21&branchName=master">
            <img src="https://dev.azure.com/phenix-project/feedstock-builds/_apis/build/status/phenix-feedstock?branchName=master">
          </a>
        </summary>
        <table>
          <thead><tr><th>Variant</th><th>Status</th></tr></thead>
          <tbody><tr>
              <td>linux_64</td>
              <td>
                <a href="https://dev.azure.com/phenix-project/feedstock-builds/_build/latest?definitionId=21&branchName=master">
                  <img src="https://dev.azure.com/phenix-project/feedstock-builds/_apis/build/status/phenix-feedstock?branchName=master&jobName=linux&configuration=linux_64_" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_64</td>
              <td>
                <a href="https://dev.azure.com/phenix-project/feedstock-builds/_build/latest?definitionId=21&branchName=master">
                  <img src="https://dev.azure.com/phenix-project/feedstock-builds/_apis/build/status/phenix-feedstock?branchName=master&jobName=osx&configuration=osx_64_" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_arm64</td>
              <td>
                <a href="https://dev.azure.com/phenix-project/feedstock-builds/_build/latest?definitionId=21&branchName=master">
                  <img src="https://dev.azure.com/phenix-project/feedstock-builds/_apis/build/status/phenix-feedstock?branchName=master&jobName=osx&configuration=osx_arm64_" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>win_64</td>
              <td>
                <a href="https://dev.azure.com/phenix-project/feedstock-builds/_build/latest?definitionId=21&branchName=master">
                  <img src="https://dev.azure.com/phenix-project/feedstock-builds/_apis/build/status/phenix-feedstock?branchName=master&jobName=win&configuration=win_64_" alt="variant">
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </details>
    </td>
  </tr>
</table>

Current release info
====================

| Name | Downloads | Version | Platforms |
| --- | --- | --- | --- |
| [![Conda Recipe](https://img.shields.io/badge/recipe-cctbx-green.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx) | [![Conda Downloads](https://img.shields.io/conda/dn/['cctbx-dev', 'main']/cctbx.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx) | [![Conda Version](https://img.shields.io/conda/vn/['cctbx-dev', 'main']/cctbx.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx) | [![Conda Platforms](https://img.shields.io/conda/pn/['cctbx-dev', 'main']/cctbx.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx) |
| [![Conda Recipe](https://img.shields.io/badge/recipe-cctbx--base-green.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx-base) | [![Conda Downloads](https://img.shields.io/conda/dn/['cctbx-dev', 'main']/cctbx-base.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx-base) | [![Conda Version](https://img.shields.io/conda/vn/['cctbx-dev', 'main']/cctbx-base.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx-base) | [![Conda Platforms](https://img.shields.io/conda/pn/['cctbx-dev', 'main']/cctbx-base.svg)](https://anaconda.org/['cctbx-dev', 'main']/cctbx-base) |

Installing phenix
=================

Installing `phenix` from the `['cctbx-dev', 'main']` channel can be achieved by adding `['cctbx-dev', 'main']` to your channels with:

```
conda config --add channels ['cctbx-dev', 'main']
conda config --set channel_priority strict
```

Once the `['cctbx-dev', 'main']` channel has been enabled, `cctbx, cctbx-base` can be installed with:

```
conda install cctbx cctbx-base
```

It is possible to list all of the versions of `cctbx` available on your platform with:

```
conda search cctbx --channel ['cctbx-dev', 'main']
```




Updating phenix-feedstock
=========================

If you would like to improve the phenix recipe or build a new
package version, please fork this repository and submit a PR. Upon submission,
your changes will be run on the appropriate platforms to give the reviewer an
opportunity to confirm that the changes result in a successful build. Once
merged, the recipe will be re-built and uploaded automatically to the
`['cctbx-dev', 'main']` channel, whereupon the built conda packages will be available for
everybody to install and use from the `['cctbx-dev', 'main']` channel.
Note that all branches in the phenix-project/phenix-feedstock are
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


# cylp-makescript

These scripts are for installing [cylp](https://github.com/coin-or/CyLP), [CBC](www.coin-or.org/download/source/Cbc/) and [cvxpy](http://www.cvxpy.org/en/latest/) in a python virtual environment.

## Context

`pip install cylp cvxpy` does not install cylp properly. The usual installation process involves compiling a lot of things manually. Even if you manually compile these dependencies, pip will forget the dependencies of the first library by the time you install the 2nd. This leads to breakages, and is a nightmare to deal with. 

These scripts handle that all for you.

This script also shrinks the size of the included libraries, so that the whole final virtual environment can fit inside the size limit imposed by AWS on their lambda functions.

## Usage

* Run `compile.sh` to compile `.whl` files for the libraries
* Run `makeScript.sh` to install these files into a virtual environment

This was split up into 2 files because compilation takes a long time, and you may want to reinstall these libraries into your virtual env, without waiting for all the dependencies to be compiled from scratch.

* `pip-list-works.txt` is a list of the libraries installed in my virtual environment, which do work. (There may be uneccessary libraries included, installed for my specific application)

    


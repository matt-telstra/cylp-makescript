#!/bin/bash

deactivate

set -e # halt if error on single line
set -x # display commands as they are run

LIB_DIR=$(pwd)/lib/
rm -rf $LIB_DIR
mkdir $LIB_DIR

COMPILE_DIR=$(pwd)/compilation-artefacts/
COMPILATION_ENV="$COMPILE_DIR/env/"
#
rm -rf  $COMPILE_DIR
mkdir $COMPILE_DIR
cd $COMPILE_DIR

virtualenv -p /usr/bin/python2.7 $COMPILATION_ENV
. $COMPILATION_ENV/bin/activate

$COMPILATION_ENV/bin/pip install "setuptools==1.4"
$COMPILATION_ENV/bin/pip install toolz
$COMPILATION_ENV/bin/pip install six
$COMPILATION_ENV/bin/pip install fastcache
$COMPILATION_ENV/bin/pip install multiprocess
$COMPILATION_ENV/bin/pip install "numpy==1.8.2" # 1.8
$COMPILATION_ENV/bin/pip install Tempita

# Step 1
echo 'downloading CBC'
rm -r Cbc-2.8.5* -f # remove stuff from previous attempt
wget https://www.coin-or.org/download/source/Cbc/Cbc-2.8.5.zip # no later than 2.8.5
unzip Cbc-2.8.5.zip

cd Cbc-2.8.5
echo 'compiling CBC'
./configure
make
make install

# Step 2
export COIN_INSTALL_DIR=$COMPILE_DIR/Cbc-2.8.5 # add to .bash_rc?

echo 'compiled CBC'

cd $COMPILE_DIR

# Step 3
echo 'downloading CyLP'
rm -r -f CyLP  # remove stuff from previous attempt
git clone https://github.com/coin-or/CyLP.git

cd CyLP
echo 'compiling CyLP'
python setup.py bdist_wheel
echo 'compiled CyLP'

cd $COMPILE_DIR

TARGET=$COMPILE_DIR/CyLP/dist/cylp-0.7.4_-cp27-cp27mu-linux_x86_64.whl

echo 'copying whl across'
cp $TARGET $LIB_DIR/

echo 'copying binaries accross'
cp $COMPILE_DIR/Cbc-2.8.5/lib/. $LIB_DIR/Cbc-bins/ -r

echo 'copying Cbc dir across as tar.gz'
# compress to tar.gz
# save result to sga/lib
cd $COMPILE_DIR/
tar -czvf $LIB_DIR/Cbc-2.8.5.tar.gz Cbc-2.8.5

echo 'compiling scipy'
cd $COMPILE_DIR


for VERSION in 0.15.0 #0.15.0rc1 0.15.0b1 0.15.0
do
    echo "compiling scipy version $VERSION"
    cd $COMPILE_DIR
    mkdir scipy-$VERSION
    cd scipy-$VERSION
    wget https://github.com/scipy/scipy/archive/v$VERSION.tar.gz
    tar -xvzf v$VERSION.tar.gz
    cd scipy-$VERSION

    echo "before"
    grep -r NPY_NO_DEPRECATED_API

    # please avert your eyes and pretend you didn't see this
    # it does a search and replace for all files in this directory
    #find $(pwd)/ -type f -exec \
    #    sed -i 's/#define\s+NPY_NO_DEPRECATED_API\s+\w+/#define NPY_NO_DEPRECATED_API NPY_1_8_API_VERSION/g' {} +
    # TODO: try with 1_8 version
    #echo "after"
    #grep -r NPY_NO_DEPRECATED_API

    python setup.py bdist_wheel
    SCIPY_WHEEL=$(pwd)/dist/scipy-$VERSION-cp27-cp27mu-linux_x86_64.whl
    cp $SCIPY_WHEEL $LIB_DIR/
    echo "finished compiling scipy version $VERSION"
done


echo 'about to compile and install scs'


deactivate

###########
# SCS
###########
# We need to run the compilation within a virtual env
# because we want to compile while running a particular version of numpy
# And then just to be sure, we'll create a fresh virtual env afterwards
# and see if we can import scs into that

SCS_DIR="$COMPILE_DIR/SCS"
rm -rf $SCS_DIR
mkdir $SCS_DIR


SCS_COMPILE_ENV="$SCS_DIR/scs-env/"
rm -rf $SCS_COMPILE_ENV
virtualenv -p /usr/bin/python2.7 $SCS_COMPILE_ENV
. $SCS_COMPILE_ENV/bin/activate

$SCS_COMPILE_ENV/bin/pip install "setuptools==1.4"
$SCS_COMPILE_ENV/bin/pip install toolz
$SCS_COMPILE_ENV/bin/pip install six
$SCS_COMPILE_ENV/bin/pip install fastcache
$SCS_COMPILE_ENV/bin/pip install multiprocess
$SCS_COMPILE_ENV/bin/pip install "numpy==1.8.2" # 1.8

$SCS_COMPILE_ENV/bin/pip install --no-binary :all: "scipy==0.15"
echo 'installed scipy, about to try importing it'
cd $COMPILE_DIR
python -c 'import scipy; print(scipy.__version__)'
echo 'sucessfully import scipy'

cd $SCS_DIR
git clone https://github.com/cvxgrp/scs.git
cd $SCS_DIR/scs/python
echo 'installing package on system'
#python setup.py install
#find $(pwd)/ -type f -exec \
#        sed -i 's/#define\s+NPY_NO_DEPRECATED_API\s+\w+/#define NPY_NO_DEPRECATED_API NPY_1_8_API_VERSION/g' {} +
python setup.py bdist_wheel

# test the module in this env
SCS_WHEEL_F_NAME=scs-1.2.6-cp27-cp27mu-linux_x86_64.whl
SCS_WHEEL_LOC=$SCS_DIR/scs/python/dist/$SCS_WHEEL_F_NAME
TARGET=$SCS_WHEEL_LOC
echo 'about to install scs from whl'
$SCS_COMPILE_ENV/bin/pip install $TARGET
#$SCS_COMPILE_ENV/bin/pip install scs
pip list --format=columns
python -c 'import scs'
find ./ libClpSolver 2> /dev/null | grep libClpSolver
if [ "$?" -eq 0 ] ; then
  echo "found something"
  #exit 1
fi
mv scs scs-backup
rm -rf scs
python -c 'import scs'
echo 'scs works in the build environment'

# copy to sga/lib
rm -rf $LIB_DIR/scs*.whl
cp $SCS_WHEEL_LOC $LIB_DIR/$SCS_WHEEL_F_NAME

deactivate

echo 'going to test scs inside a fresh env'
TEST_ENV="$SCS_DIR/test-env"
rm -rf $TEST_ENV
virtualenv -p /usr/bin/python2.7 $TEST_ENV
. $TEST_ENV/bin/activate

$TEST_ENV/bin/pip install "setuptools==1.4"
$TEST_ENV/bin/pip install toolz
$TEST_ENV/bin/pip install six
$TEST_ENV/bin/pip install fastcache
$TEST_ENV/bin/pip install multiprocess
$TEST_ENV/bin/pip install "numpy==1.8.2" # 1.8
$TEST_ENV/bin/pip install "scipy==0.15"
TARGET=$LIB_DIR/$SCS_WHEEL_F_NAME
$TEST_ENV/bin/pip install $TARGET
echo 'about to test import in clean env'
python -c 'import scs'
echo 'it works!'
echo 'done'

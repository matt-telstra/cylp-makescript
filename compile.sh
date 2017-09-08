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
    SCIPY_WHL_F="scipy-$VERSION-cp27-cp27mu-linux_x86_64.whl"
    SCIPY_WHEEL=$(pwd)/dist/$SCIPY_WHL_F
    cp $SCIPY_WHEEL $LIB_DIR/$SCIPY_WHL_F
    echo "finished compiling scipy version $VERSION"
done


echo 'about to compile and install scs'


deactivate

###########
# libopenblas
###########
# compile this library to get libopenblas.so.0
# which is needed by SCS
# TODO: see if the make install line up the top puts this file somewhere
BLAS_DIR=$COMPILE_DIR/blas
rm -rf $BLAS_DIR
mkdir $BLAS_DIR
BLAS_ENV=$BLAS_DIR/env
virtualenv -p /usr/bin/python2.7 $BLAS_ENV # not sure if necessary
. $BLAS_ENV/bin/activate
cd $BLAS_DIR
git clone https://github.com/xianyi/OpenBLAS.git
cd ./OpenBLAS
make
mkdir $LIB_DIR/bin/ -p
cp $BLAS_DIR/OpenBLAS/libopenblas.so.0 $LIB_DIR/bin/libopenblas.so.0

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

# Must concatenate all libraries into 1
# otherwise pip forgets dependencies
TARGET=""
TARGET=$TARGET" setuptools==1.4"
TARGET=$TARGET" toolz"
TARGET=$TARGET" six"
TARGET=$TARGET" fastcache"
TARGET=$TARGET" multiprocess"
TARGET=$TARGET" numpy==1.8.2" # 1.8
TARGET=$TARGET" $LIB_DIR/$SCIPY_WHL_F"
pip install $TARGET
#pip install --no-binary :all: "scipy==0.15"
echo 'installed scipy, about to try importing it'
cd $COMPILE_DIR
python -c 'import scipy; print(scipy.__version__)'
python -c 'import scipy; assert(scipy.__version__ == "0.15.0")'
echo 'sucessfully import scipy'

cd $SCS_DIR
# git clone https://github.com/cvxgrp/scs.git # can't use this, since version changed
# TODO: test version 1.2.7 of SCS
wget https://github.com/cvxgrp/scs/archive/v1.2.6.tar.gz
tar -xzf v1.2.6.tar.gz

cd $SCS_DIR/scs-1.2.6/python
echo 'installing package on system'
#python setup.py install
#find $(pwd)/ -type f -exec \
#        sed -i 's/#define\s+NPY_NO_DEPRECATED_API\s+\w+/#define NPY_NO_DEPRECATED_API NPY_1_8_API_VERSION/g' {} +
python setup.py bdist_wheel

# test the module in this env
SCS_WHEEL_F_NAME=scs-1.2.6-cp27-cp27mu-linux_x86_64.whl
SCS_WHEEL_SRC=$SCS_DIR/scs-1.2.6/python/dist/$SCS_WHEEL_F_NAME
SCS_WHEEL_DST=$LIB_DIR/$SCS_WHEEL_F_NAME
cp $SCS_WHEEL_SRC $SCS_WHEEL_DST
echo 'about to install scs from whl'
pip install $SCS_WHEEL_DST
SCS_COMPILE_ENV_BIN=$SCS_COMPILE_ENV/lib/python2.7/site-packages/lib/
echo 'making empty bin file for scs compile env'
mkdir -p $SCS_COMPILE_ENV_BIN
cp $LIB_DIR/bin/libopenblas.so.0 $SCS_COMPILE_ENV_BIN/libopenblas.so.0
OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$SCS_COMPILE_ENV_BIN/:$LD_LIBRARY_PATH
pip list --format=columns > $COMPILE_DIR/scs_pip.txt
python -c 'import scipy; assert(scipy.__version__ == "0.15.0")'
python -c 'import scs'
# find ./ libClpSolver 2> /dev/null | grep libClpSolver
#if [ "$?" -eq 0 ] ; then
#  echo "found something"
#  #exit 1
#fi

deactivate

echo 'going to test scs inside a fresh env'
TEST_ENV="$SCS_DIR/test-env"
rm -rf $TEST_ENV
virtualenv -p /usr/bin/python2.7 $TEST_ENV
. $TEST_ENV/bin/activate

TARGET=""

TARGET=$TARGET" setuptools==1.4"
TARGET=$TARGET" toolz"
TARGET=$TARGET" six"
TARGET=$TARGET" fastcache"
TARGET=$TARGET" multiprocess"
TARGET=$TARGET" numpy==1.8.2" # 1.8
TARGET=$TARGET" $LIB_DIR/$SCIPY_WHL_F"
TARGET=$TARGET" "$SCS_WHEEL_DST
echo "about to install: "$TARGET
echo $TARGET > $COMPILE_DIR/target_clean.txt
pip install $TARGET
#pip install $SCS_WHL_DST

TEST_ENV_BIN=$TEST_ENV/lib/python2.7/site-packages/lib/
echo 'making empty bin file for scs compile env'
mkdir -p $TEST_ENV_BIN
cp $LIB_DIR/bin/libopenblas.so.0 $TEST_ENV_BIN/libopenblas.so.0
export LD_LIBRARY_PATH=$TEST_ENV_BIN/:$OLD_LD_LIBRARY_PATH


echo 'about to test import in clean env'

pip list --format=columns > $COMPILE_DIR/clean_pip.txt

python -c 'import scipy; print(scipy.__version__)'
python -c 'import scipy; assert(scipy.__version__ == "0.15.0")'
python -c 'import scs'
echo 'it works!'
export LD_LIBRARY_PATH=$OLD_LD_LIBRARY_PATH
echo 'done'


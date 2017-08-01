## disable, to make buildable for CJ
#rm -rf worker-env  # remove stuff from previous attempt
#virtualenv -p /usr/bin/python2.7 ./worker-env
#exit


set -e
set -x

# check number of arguments
if [ "$#" -ne 1 ] || ! [ -d "$1" ]; then
  echo "Usage: $0 SGADIR" >&2
  exit 1
fi


rm -rf worker-env  # remove stuff from previous attempt
virtualenv -p /usr/bin/python2.7 ./worker-env

. ./worker-env/bin/activate

# list of packages to install
# do it all in one go
# because otherwise pip won't notice clashing dependencies
# e.g. if the first package requires numpy<=1, but second package requires numpy>=2

TARGETS=""

TARGETS="$TARGETS setuptools==1.4"
TARGETS="$TARGETS toolz==0.8.2" # not sure if version specification is necessary
TARGETS="$TARGETS six==1.10.0" # not sure if version specification is necessary
TARGETS="$TARGETS fastcache==1.0.2"  # not sure if version specification is necessary
TARGETS="$TARGETS multiprocess==0.70.5" # not sure if version specification is necessary
TARGETS="$TARGETS numpy==1.12.1" # version specification definitely necessary
TARGETS="$TARGETS scipy==0.15"  # version specification definitely necessary

# Install SCS
SCS_WHEEL_F_NAME=scs-1.2.6-cp27-cp27mu-linux_x86_64.whl
TARGET=$1/lib/$SCS_WHEEL_F_NAME
TARGETS="$TARGETS $TARGET"

rm -rf scs

./worker-env/bin/pip install $TARGETS
TARGETS=""

TARGETS="$TARGETS ECOS==2.0.3" # 2.0.3 and 2.0.2  and 2.0.1 works
TARGETS="$TARGETS cvxpy==0.4.10"
TARGETS="$TARGETS cvxcanon==0.0.22"

COMPILATION_DIR="$1/lambda/functions/genestimate/compilation-artefacts"

if [ ! -d "$COMPILATION_DIR" ]; then
    # make the directory if it doesn't exist
    mkdir $COMPILATION_DIR
fi

rm -rf $COMPILATION_DIR/makeStuff
mkdir $COMPILATION_DIR/makeStuff
tar -xzvf $1/lib/Cbc-2.8.5.tar.gz -C $COMPILATION_DIR/makeStuff

COIN_INSTALL_DIR="$COMPILATION_DIR/makeStuff/Cbc-2.8.5/"
export COIN_INSTALL_DIR="$COMPILATION_DIR/makeStuff/Cbc-2.8.5/"

TARGETS="$TARGETS cylp==0.2.3.6"
TARGETS="$TARGETS nose"

# sga common
for fn in Strategies Api Consts Tools Market Iot SNS; do
    TARGET="file://$1/lib/sgacommon$fn/"
    TARGETS="$TARGETS $TARGET"
done

# I think sgacommon stuffs up some things
# so reinstall the version of numpy we want
# because pip forget what we asked for earlier
TARGETS="$TARGETS numpy==1.12.1"

./worker-env/bin/pip install $TARGETS

cp $1/lib/Cbc-bins/. ./worker-env/lib/python2.7/site-packages/lib/ -r
cp "$1/lib/shared_libraries/liblapack.so.3" ./worker-env/lib/python2.7/site-packages/lib/
cp "$1/lib/shared_libraries/libblas.so.3" ./worker-env/lib/python2.7/site-packages/lib/
cp "$1/lib/shared_libraries/libgfortran.so.3" ./worker-env/lib/python2.7/site-packages/lib/
cp "$1/lib/shared_libraries/libquadmath.so.0" ./worker-env/lib/python2.7/site-packages/lib/
cp "$1/lib/shared_libraries/libClpSolver.so.1" ./worker-env/lib/python2.7/site-packages/lib/


export LD_LIBRARY_PATH=$(pwd)/worker-env/lib/python2.7/site-packages/lib/:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$(pwd)/worker-env/lib64/python2.7/site-packages/lib/:$LD_LIBRARY_PATH

# delete needless files to save space
# TODO: add flush.py to sga/lib
# so there's only 1 copy of it
find ./worker-env/lib/python2.7/site-packages/ -regextype sed -regex ".*so$" -exec strip {} \;
python $1/lib/flush.py

python -c 'import scs'
python -c 'import ecos'
python -c 'import cvxpy'
python -c 'import CVXcanon'
python -c 'import scipy;'
python -c 'import cylp'


# save this into the git repo, just to keep things trackable over time
echo 'saving output of pip-list'
./worker-env/bin/pip list --format=columns > pip-list-current.txt

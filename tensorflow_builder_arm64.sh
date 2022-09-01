# run this, for example inside a docker container with the right toolkit
# plus the right storage ( let's use the SSD as a temp disk instead of the docker overlay fs ...)

# IMPORTANT NOTES
#  - libprotobuf 3.19.0 and later _breaks_ all of the backwards compatiblity required by tensorflow
#  - this file documents the CURRENTLY USED VERSION OF THIRD PARTY DEPS IN tensorflow v2.8.x 
#
# TENSORFLOW v2.8.x IS THE LAST BRANCH THAT USES _GLIBCXX_USE_CXX11_ABI=0 WHEN BUILDING
#                   AS OMEGA2 2023 STILL DOES ...
#                   see https://gcc.gnu.org/onlinedocs/libstdc++/manual/using_dual_abi.html
#                   IN PRACTICE IT CHANGES HOW OLDER C++ CAN BE LINKED WITH NEWER ONE
#                   OR OLDER C++1x AND NEWER C++1y ...
#                   std::__cxx11 mangling and implemntation of std types and  [abi:cxx11] errors are what is expected.
#
#                   THIS _HAS KNOCK ON EFFECTS DOWNSTREAMS_
#                   SO THIS IS THE LAST VERSION OF TENSORFLOW THAT CAN BE LINKED WITH OMEGA 2023 AND EARLIER.

# configure bazel so that the /root/.cache/bazel directory isn't used?
BAZEL_RELEASE=4.2.1
# v2.8.0 known to work
# v2.8.2 brings _shitloads of security fixes ON libz, libcurl, and TENSORFLOW ITSELF
# zlib 1.2.11 -> 1.2.12
# curl 7.79.1 -> 7.83.1

TENSORFLOW_RELEASE_TAG=v2.8.2

# it is currently my understanding that
# tensorflow v2.8.0 uses
# protobuf v3.9.2
# abseil-cpp 20210324.0

#
# grpc ... somewhere near v1.27.0 but not in apis
# google-cloud-cpp-1.17.1
cd /ssd && git clone --filter=blob:none --depth 1 --recursive -b ${TENSORFLOW_RELEASE_TAG} https://github.com/tensorflow/tensorflow 

# can I do this without interaction ?
mkdir -p /ssd/out/{lib64,include,proto,generated}

# replace ${HOME}/.cache/bazel in our case /root/.cache/bazel
# that is _inside the container folder with an out-of-overlay COW fs one...
mkdir /ssd/bazel_output_{user_root,base}

export TF_NEED_CUDA=0
export TF_NEED_HDFS=0
export TF_NEED_S3=0
export TF_NEED_ROCM=0
# do we want this ?
export TF_NEED_GCP=1
# this is mkl dnn not mkl. (not used naymore?")
export TF_NEED_MKL=1
export TF_ENABLE_XLA=1
# we aren't on x86_64 or amd64 anymore, this is arm64 v 8 ...  ( does MKL make sense ?)
#export CC_OPT_FLAGS='-mavx2 -O3 -Wno-sign-compare'
export CC_OPT_FLAGS='-march=native -O3 -Wno-sign-compare'
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0

# need to set PYTHON_BIN_PATH and PYTHON_LIB_PATH 
export PYTHON_BIN_PATH=/opt/rh/rh-python38/root/usr/bin/python
export PYTHON_LIB_PATH=/opt/rh/rh-python38/root/usr/lib/python3.8/site-packages

cd /ssd/tensorflow
scl enable rh-python38 devtoolset-7 \
    './configure'

# --output_user_root or --output_base start with bazel version ... 
# it also change the incrememntal state?

pwd
scl enable rh-python38 devtoolset-7 \
    'bazel --output_user_root /ssd/bazel_output_user_root build -c opt //tensorflow:libtensorflow_cc.so --config=mkl --config="opt" --config="monolithic" --copt="-march=native" --spawn_strategy=standalone --genrule_strategy=standalone --verbose_failures'

pwd

cp  --no-dereference  bazel-bin/tensorflow/libtensorflow_* /ssd/out/lib64
# does that name depende on the --config=mkl choice ?
cp  /ssd/tensorflow/bazel-bin/tensorflow/../_solib_k8/_U_S_Sthird_Uparty_Smkl_Cmkl_Ulibs_Ulinux___Uexternal_Sllvm_Uopenmp/libiomp5.so /ssd/out/lib64/


# copy static pic libs for absl ? protobuf? grpc??

workarea=/ssd/out
# copy includes and third party deps includes ???
rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
      --include='*/' --exclude='*_test.h' --exclude='testutil.h' \
      --exclude='*_testutil.h' --include='*.h' --exclude='*' \
      --prune-empty-dirs \
      tensorflow/cc tensorflow/core third_party/eigen3 ${workarea}/include/  \
|| echo "failed to copy tensorflow includes"

# copy protos.
rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
      --include='*/' --exclude='*_test.h' --exclude='testutil.h' --exclude='*_testutil.h' \
      --include='*.proto'  --exclude='*' \
      --prune-empty-dirs \
      tensorflow/cc tensorflow/core third_party/eigen3 ${workarea}/proto/  \
|| echo "failed to copy tensorflow protos"

rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
      --include='*/' --prune-empty-dirs \
      third_party/eigen3 unsupported/Eigen ${workarea}/include/   \
|| echo "failed to copy eigen3 and unsupported/Eigen includes"

pushd bazel-bin
rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
      --include='*/' --exclude='*_test.h' --exclude='testutil.h' \
      --exclude='*_testutil.h' --include='*.pb.h' --include='*.pb.cc'  --exclude='*' \
      --prune-empty-dirs \
      tensorflow ${workarea}/generated/ \
|| echo "failed to copy generate .pb.h and .pb.cc from tensorflow"
popd

# this stuff appears to be missing.
# trying hard to make it work
# this install some duplicate _idenitcal_ .pb.h in generated and include
rsync --verbose --relative --recursive --human-readable --stats --itemize-changes \
      --exclude='*ops_internal.h' \
      --include='*.pb.h' --include='*.h' --include='*.pb_text.h' --include='*.pb_text-impl.h'  \
      --exclude='*_test.h' --exclude='testutil.h' --exclude='*_testutil.h' \
      --exclude='*ops_internal.h' \
      --exclude='*ops_internal.cc' \
      --exclude='*ops_gen_cc*' \
      --exclude='*runfiles*' \
      --exclude='*manifest' --exclude='MANIFEST' \
      --exclude='*.cc'      --exclude='*.o'    --exclude='*.d'  --exclude='*params' \
      --include='tensorflow/cc/ops/*' \
      --include='tensorflow/core/framework/*' \
      --include='tensorflow/core/framework/registration/*' \
      --prune-empty-dirs \
      tensorflow/cc/ops tensorflow/core/framework  ${workarea}/include/ \
|| echo "failed to copy missing include files"

# download source as well ? download  .pic.a  libraries?
pushd bazel-tensorflow/external/
pushd com_google_absl
rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
    --include='*/' --exclude='*_test.h' --exclude='testutil.h' --exclude='*_testutil.h' \
    --include='*.h' --include='*.inc' --exclude='*' \
    --prune-empty-dirs \
    absl ${workarea}/include/    \
|| echo "failed to copy abseil-cpp includes"
popd

pushd eigen_archive
rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
    --include='*/' \
    --prune-empty-dirs \
    unsupported/Eigen Eigen ${workarea}/include/   \
|| echo "failed to copy Eigen includes"
popd

pushd com_google_protobuf/src
rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
    --include='*/' --exclude='*_test.h' --exclude='testutil.h' --exclude='*_testutil.h' \
    --include='*.h' --include='*.inc' --exclude='*' \
    --prune-empty-dirs \
    google/protobuf  ${workarea}/include/ \
|| echo "failed to copy protobuf include"

rsync --verbose --relative --recursive --human-readable  --stats --itemize-changes \
    --include='*/' --exclude='*_test.h' --exclude='testutil.h' --exclude='*_testutil.h' \
    --include='*.proto' --exclude='*' \
    --prune-empty-dirs \
    google/protobuf  ${workarea}/proto/ \
|| echo "failed to copy protobuf proto"
popd



# I don't yet know how to produce .a or .pic.a files for protobuf and abseil
# go to the build areas and pack all the source, .o, etc ???

popd

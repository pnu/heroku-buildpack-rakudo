#!/usr/bin/env bash
set -e

BUILD_PATH=/tmp/build-rakudo
VENDOR_PATH=/app/vendor/rakudo

mkdir -p $BUILD_PATH
mkdir -p $VENDOR_PATH

cd $BUILD_PATH
git clone https://github.com/rakudo/rakudo.git
git clone https://github.com/perl6/nqp.git
git clone https://github.com/MoarVM/MoarVM.git
git clone --recursive git://github.com/tadzik/panda.git
git clone https://github.com/s3tools/s3cmd

if [ -n "$RAKUDO_REVISION" ]; then
    cd $BUILD_PATH/rakudo
    git checkout $RAKUDO_REVISION
fi
cd $BUILD_PATH/nqp
git checkout `cat $BUILD_PATH/rakudo/tools/build/NQP_REVISION`
cd $BUILD_PATH/MoarVM
git checkout `cat $BUILD_PATH/nqp/tools/build/MOAR_REVISION`

cd $BUILD_PATH/MoarVM
perl ./Configure.pl --prefix=$VENDOR_PATH
make install
cd $BUILD_PATH/nqp
perl ./Configure.pl --backends=moar --prefix=$VENDOR_PATH
make install
cd $BUILD_PATH/rakudo
perl ./Configure.pl --prefix=$VENDOR_PATH
make install
RAKUDO_REVISION=`git describe`

export PATH=$VENDOR_PATH/bin:$PATH
export PATH=$VENDOR_PATH/languages/perl6/site/bin:$PATH

cd $BUILD_PATH/panda
perl6 bootstrap.pl
panda install --notests DBIish

cd $BUILD_PATH
tar czf rakudo-$RAKUDO_REVISION.tgz -C $VENDOR_PATH .

cd $BUILD_PATH/s3cmd
git checkout v1.5.0-beta1
cat >~/.s3cfg <<EOF
[default]
access_key = $AWS_ACCESS_KEY_ID
secret_key = $AWS_SECRET_ACCESS_KEY
use_https = True
EOF

./s3cmd put --acl-public $BUILD_PATH/rakudo-$RAKUDO_REVISION.tgz s3://$S3_BUCKET_NAME

#!/usr/bin/env bash
set -e

RAKUDO_CONFIGURE_OPTS=${RAKUDO_CONFIGURE_OPTS-'--gen-moar --gen-nqp --backends=moar'}
RAKUDO_DIST_NAME=${RAKUDO_DIST_NAME-'rakudo'}

HEROKU_STACK=${HEROKU_STACK-'cedar-14'}
BUILD_PATH="/tmp/build-rakudo-$$"
VENDOR_PATH="/app/vendor/rakudo"
mkdir -p $BUILD_PATH
mkdir -p $VENDOR_PATH
exec  > >(tee -a $BUILD_PATH/log)
exec 2> >(tee -a $BUILD_PATH/log >&2)

cd $BUILD_PATH
git clone https://github.com/rakudo/rakudo.git
git clone --recursive git://github.com/tadzik/panda.git
git clone https://github.com/s3tools/s3cmd


echo "### BUILD $RAKUDO_DIST_NAME ($RAKUDO_REVISION) / $RAKUDO_CONFIGURE_OPTS ###"

cd $BUILD_PATH/rakudo
if [ -n "$RAKUDO_REVISION" ]; then
    git checkout $RAKUDO_REVISION
fi
perl Configure.pl $RAKUDO_CONFIGURE_OPTS --prefix=$VENDOR_PATH
make test
make install

export PATH=$VENDOR_PATH/bin:$PATH
export PATH=$VENDOR_PATH/languages/perl6/site/bin:$PATH
export PATH=$VENDOR_PATH/share/perl6/site/bin:$PATH
RAKUDO_VERSION=`perl6 -e'print $*PERL.compiler.version'`


echo "### INSTALL Task::Star ###"

cd $BUILD_PATH/panda
perl6 bootstrap.pl || true
panda --notests install DBIish || true
panda install Task::Star || { TASK_STAR_FAIL=1; }

cd $BUILD_PATH
tar cvzf $RAKUDO_DIST_NAME-$RAKUDO_VERSION.tgz -C $VENDOR_PATH .


echo "### UPLOAD $RAKUDO_DIST_NAME-$RAKUDO_VERSION ###"

cd $BUILD_PATH/s3cmd
git checkout v1.5.0-beta1
cat >~/.s3cfg <<EOF
[default]
access_key = $AWS_ACCESS_KEY_ID
secret_key = $AWS_SECRET_ACCESS_KEY
use_https = True
EOF

./s3cmd put --acl-public $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION.tgz s3://$S3_BUCKET_NAME/$HEROKU_STACK/
cp $BUILD_PATH/log $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION.log
./s3cmd put --acl-public $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION.log s3://$S3_BUCKET_NAME/$HEROKU_STACK/


echo "### TEST panda smoke ###"
cd $BUILD_PATH/panda
PANDA_SUBMIT_TESTREPORTS=1 panda smoke || true

echo "### TEST spectest ###"
cd $BUILD_PATH/rakudo
make spectest || { SPECTEST_FAIL=1; }

echo "### UPLOAD log ###"
cd $BUILD_PATH/s3cmd
cp $BUILD_PATH/log $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION-test.log
./s3cmd put --acl-public $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION-test.log s3://$S3_BUCKET_NAME/$HEROKU_STACK/

if [ -z "$RAKUDO_REVISION" ] && [ -z "$TASK_STAR_FAIL" ] && [ -z "$SPECTEST_FAIL" ]; then
    echo "### UPLOAD $RAKUDO_DIST_NAME-latest and logs ###"
    ./s3cmd put --acl-public $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION.tgz s3://$S3_BUCKET_NAME/$HEROKU_STACK/$RAKUDO_DIST_NAME-latest.tgz
    ./s3cmd put --acl-public $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION.log s3://$S3_BUCKET_NAME/$HEROKU_STACK/$RAKUDO_DIST_NAME-latest.log
    ./s3cmd put --acl-public $BUILD_PATH/$RAKUDO_DIST_NAME-$RAKUDO_VERSION-test.log s3://$S3_BUCKET_NAME/$HEROKU_STACK/$RAKUDO_DIST_NAME-latest-test.log
fi


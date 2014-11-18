Heroku buildpack: Rakudo Perl 6
===============================

Usage
-----

    $ git init
    $ cat >META.info
    {}
    ^D
    $ git add -A; git commit -m 'implement the app'
    $ heroku create --buildpack https://github.com/pnu/heroku-buildpack-rakudo
    $ git push heroku master

Compiling rakudo
----------------

Script `support/rakudo-build.sh` can be used to build your own rakudo versions.
The build script runs on Heroku, and uploads the compiled package to a S3 bucket.
S3 credentials and bucket name are specified in the environment.

    $ heroku create     # create a build server, eg. your-app-1234
    $ heroku config:set AWS_ACCESS_KEY_ID="xxx" AWS_SECRET_ACCESS_KEY="yyy" S3_BUCKET_NAME="heroku-buildpack-rakudo" HEROKU_STACK="cedar-14" --app your-app-1234
    $ heroku run 'curl -sL https://raw.github.com/pnu/heroku-buildpack-rakudo/master/support/rakudo-build.sh | RAKUDO_REVISION="nnn" bash' --app your-app-1234
    [...]
    $ heroku destroy --app your-app-1234 --confirm your-app-1234

You can use the same build server to build multiple versions concurrently.
Environment variable `RAKUDO_REVISION` specifies the rakudo version to build.
It can be anything that works for `git checkout`. If not specified, default
is HEAD of the default branch.

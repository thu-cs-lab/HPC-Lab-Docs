#!/bin/bash

sed -i -r 's/^(# .*)\{: .page-title\}/\1/' $1
sed -i -r '/.*\{: .page-title\}/d' $1

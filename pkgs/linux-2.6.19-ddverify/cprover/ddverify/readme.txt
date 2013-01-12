This package contains a compiled version of DDVerify and Satabs.

1. INSTALL
-----------------------

To install DDVerify the following steps must be done:
- set the environment variable DDV_PATH to this directory
- add the binary directory of DDVerify to the PATH.
- you need to install either Boppo or Cadence SMV.


2. EXECUTE
-----------------------

Type "ddverify --help" to get more
information about ddverify.


3. COMPILE
-----------------------

To recompile DDVerify go to the bin/ directory of DDVerify and run:

   gcc ddverfiy.c -o ddverify


4. RUN CASE STUDIES
-----------------------

The directory case_studies/ contains 31 device drivers that can be used with
DDVerify, extracted from Linux 2.6.19.  Note that we are aware of many
issues when trying to verify the benchmarks with satabs.  We offer this
collection as it is for research purpose.


5. CONTACT INFORMATION
-----------------------

If you need more information about DDVerify or you have any comments, please 
contact:

   kroening@comlab.ox.ac.uk
   nicolas.blanc@inf.ethz.ch


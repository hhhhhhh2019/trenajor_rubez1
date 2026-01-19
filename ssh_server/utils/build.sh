cc -static ./generator.c -o generator
cc -static ./checker.c -o checker
# setcap CAP_DAC_OVERRIDE=+ep checker

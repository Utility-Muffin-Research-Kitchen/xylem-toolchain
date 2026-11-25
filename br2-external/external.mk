# Changes to Buildroot's own package recipes. external.mk is read after every
# package's .mk, and a recipe's configure options are expanded only when it
# runs, so an option added here comes after the recipe's own and wins.
#
# Each of these changes what the library exports, so xylem's image has to
# make the same change, or the SDK links against something the device lacks.

# libxcrypt: Buildroot builds it --disable-obsolete-api, which gives
# libcrypt.so.2 only. Leaf's shipped ssh-server and dropbear need
# libcrypt.so.1 with glibc's old symbol versions (crypt@GLIBC_2.17), so build
# the compat API: libcrypt.so.1, glibc's versions for old binaries, XCRYPT_2.0
# for new links. The last --enable/--disable on the line wins.
LIBXCRYPT_CONF_OPTS += --enable-obsolete-api=glibc

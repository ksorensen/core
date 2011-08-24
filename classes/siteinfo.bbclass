# BitBake class to handle CONFIG_SITE variable for GNU Autoconf
# configure scripts.  Leverage base_arch.bbclass as much as possible.

# Recipes that need to query architecture specific knowledge, such as
# endianness or word size should use functions provided by
# base_arch.bbclass, as this class is only related to actual
# CONFIG_SITE handling.

# Export CONFIG_SITE to the enviroment. Autoconf generated configure
# scripts will make use of this to determine where to load in
# variables from.
export CONFIG_SITE = "${HOST_CONFIG_SITE}"

STAGE_SITE_DIR		= "${STAGE_DIR}/siteinfo"
BUILD_CONFIG_SITE	= "${STAGE_SITE_DIR}/build.site"
HOST_CONFIG_SITE	= "${STAGE_SITE_DIR}/host.site"
TARGET_CONFIG_SITE	= "${STAGE_SITE_DIR}/target.site"

BUILD_SITEFILES		= "common\
 ${BUILD_BASEOS}\
 ${BUILD_OS}\
 ${BUILD_CPU}\
 ${BUILD_CPU}-${BUILD_VENDOR}\
 ${BUILD_CPU}-${BUILD_OS}\
 bit-${BUILD_WORDSIZE}\
 endian-${BUILD_ENDIAN}e\
"

HOST_SITEFILES		= "common\
 ${HOST_BASEOS}\
 ${HOST_OS}\
 ${HOST_CPU}\
 ${HOST_CPU}-${HOST_VENDOR}\
 ${HOST_CPU}-${HOST_OS}\
 bit-${HOST_WORDSIZE}\
 endian-${HOST_ENDIAN}e\
"

TARGET_SITEFILES		= "common\
 ${TARGET_BASEOS}\
 ${TARGET_OS}\
 ${TARGET_CPU}\
 ${TARGET_CPU}-${TARGET_VENDOR}\
 ${TARGET_CPU}-${TARGET_OS}\
 bit-${TARGET_WORDSIZE}\
 endian-${TARGET_ENDIAN}e\
"

addtask siteinfo after do_patch	before do_configure
do_siteinfo[cleandirs]	= "${STAGE_SITE_DIR}"
do_siteinfo[dirs]	= "${STAGE_SITE_DIR}"

python do_siteinfo () {
    import os

    build_arch = d.getVar('BUILD_ARCH', True)
    host_arch = d.getVar('HOST_ARCH', True)
    target_arch = d.getVar('TARGET_ARCH', True)

    build_config_site = d.getVar('BUILD_CONFIG_SITE', True)
    host_config_site = d.getVar('HOST_CONFIG_SITE', True)
    target_config_site = d.getVar('TARGET_CONFIG_SITE', True)

    def generate_siteinfo(d, arch, output_filename):
        import bb, fileinput
        input_files = list_sitefiles(d, arch)
        output_file = open(output_filename, 'w')
        for line in fileinput.input(input_files):
            output_file.write(line)
        output_file.close()

    generate_siteinfo(d, 'BUILD', build_config_site)

    if host_arch == build_arch:
        os.symlink(build_config_site, host_config_site)
    else:
        generate_siteinfo(d, 'HOST', host_config_site)

    if target_arch == build_arch:
        os.symlink(build_config_site, target_config_site)
    elif target_arch == host_arch:
        os.symlink(host_config_site, target_config_site)
    else:
        generate_siteinfo(d, 'TARGET', TARGET_config_site)
}

#
# Return list of sitefiles found by searching for sitefiles in the
# ${BBPATH}/site directories and any files listed in
# ${SRC_*_SITEFILES} for * in BUILD, HOST, TARGET.
#
# The SRC_*_SITEFILES come last, so they override any variables from
# common sitefiles.
#
# TODO: could be extended with searching in stage dir, so build
# dependencies could provide sitefiles instead of piling everything
# into common files.  When building for MACHINE_ARCH, search for
# sitefiles in stage/machine/usr/share/config.site/* and each build#
# dependency should then install their files into it's own config.site
# subdir.
#
def list_sitefiles(d, arch):
    import bb, os
    found = []
    sitefiles = d.getVar(arch+'_SITEFILES', True).split()
    bbpath = d.getVar('BBPATH', True) or ''
    pv = d.getVar('PV', True)

    # 1) ${BBPATH}/site
    for path in bbpath.split(':'):
        for filename in sitefiles:
            filepath = os.path.join(path, 'site', filename)
            if filepath not in found and os.path.exists(filepath):
                found.append(filepath)

    # 2) Recipe specified files (ie. in ${SRCDIR})
    sitefiles = (d.getVar("SRC_%s_SITEFILES"%(arch), True) or "").split()
    for filepath in sitefiles:
        if filepath not in found and os.path.exists(filepath):
            found.append(filepath)

    return found
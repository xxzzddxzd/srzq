#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "../Sources/BypassShared.h"

static void test_jailbreak_paths_are_hidden(void) {
    assert(sb_is_sensitive_jb_path("/var/jb/usr/lib/libjailbreak.dylib"));
    assert(sb_is_sensitive_jb_path("/private/preboot/123456/procursus/bin/bash"));
    assert(sb_is_sensitive_jb_path("/Applications/Sileo.app"));
    assert(sb_is_sensitive_jb_path("/Library/MobileSubstrate/DynamicLibraries/Foo.dylib"));
    assert(!sb_is_sensitive_jb_path("/var/mobile/Containers/Data/Application/ABC/Documents/save.dat"));
    assert(!sb_is_sensitive_jb_path(NULL));
}

static void test_probe_writes_are_denied_without_breaking_app_logs(void) {
    assert(sb_should_deny_write_probe("/private/jailbreak.txt"));
    assert(sb_should_deny_write_probe("/var/mobile/jbprobe.txt"));
    assert(!sb_should_deny_write_probe("/var/mobile/Library/SoccerAppBypass/000001-request.bin"));
    assert(!sb_should_deny_write_probe("/var/mobile/Containers/Data/Application/ABC/tmp/cache.dat"));
}

static void test_injection_images_are_hidden(void) {
    assert(sb_is_injection_image_name("/var/jb/usr/lib/TweakInject.dylib"));
    assert(sb_is_injection_image_name("/usr/lib/libsubstrate.dylib"));
    assert(sb_is_injection_image_name("/usr/lib/libellekit.dylib"));
    assert(sb_is_injection_image_name("/usr/lib/frida/frida-agent.dylib"));
    assert(sb_is_injection_image_name("/Library/MobileSubstrate/DynamicLibraries/SoccerAppBypass.dylib"));
    assert(!sb_is_injection_image_name("/System/Library/Frameworks/Foundation.framework/Foundation"));
    assert(!sb_is_injection_image_name(NULL));
}

static void test_log_file_names_are_stable(void) {
    char out[64];

    assert(sb_make_log_basename(1, "request", out, sizeof(out)) == 0);
    assert(strcmp(out, "000001-request.bin") == 0);

    assert(sb_make_log_basename(42, "response", out, sizeof(out)) == 0);
    assert(strcmp(out, "000042-response.bin") == 0);

    assert(sb_make_log_basename(7, "meta", out, sizeof(out)) == 0);
    assert(strcmp(out, "000007-meta.txt") == 0);

    assert(sb_make_log_basename(7, "request", out, 8) == -1);
    assert(sb_make_log_basename(7, NULL, out, sizeof(out)) == -1);
}

#if 0
static void test_metadata_size_is_derived_from_header_pairs(void) {
    unsigned int header[64] = {0};
    header[0] = 0xFAB11BAF;
    header[1] = 31;
    header[2] = 0x100;
    header[3] = 0x20;
    header[4] = 0x120;
    header[5] = 0x40;
    header[6] = 0x200;
    header[7] = 0x30;

    assert(sb_metadata_size_from_header(header, sizeof(header)) == 0x230);

    header[0] = 0;
    assert(sb_metadata_size_from_header(header, sizeof(header)) == 0x230);
    assert(sb_metadata_header_needs_magic_repair(header, sizeof(header)));

    sb_repair_metadata_magic(header, sizeof(header));
    assert(header[0] == 0xFAB11BAF);
    assert(!sb_metadata_header_needs_magic_repair(header, sizeof(header)));
}
#endif

int main(void) {
    test_jailbreak_paths_are_hidden();
    test_probe_writes_are_denied_without_breaking_app_logs();
    test_injection_images_are_hidden();
    test_log_file_names_are_stable();
#if 0
    test_metadata_size_is_derived_from_header_pairs();
#endif
    puts("shared helper tests passed");
    return 0;
}

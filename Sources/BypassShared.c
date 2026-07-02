#include "BypassShared.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

#define SB_IL2CPP_METADATA_MAGIC 0xFAB11BAFu

static bool sb_ascii_contains_ci(const char *haystack, const char *needle) {
    if (!haystack || !needle || !*needle) {
        return false;
    }

    size_t needle_len = strlen(needle);
    for (const char *p = haystack; *p; p++) {
        size_t i = 0;
        while (i < needle_len && p[i]) {
            unsigned char a = (unsigned char)p[i];
            unsigned char b = (unsigned char)needle[i];
            if (tolower(a) != tolower(b)) {
                break;
            }
            i++;
        }
        if (i == needle_len) {
            return true;
        }
    }

    return false;
}

static bool sb_starts_with(const char *s, const char *prefix) {
    if (!s || !prefix) {
        return false;
    }
    return strncmp(s, prefix, strlen(prefix)) == 0;
}

bool sb_is_sensitive_jb_path(const char *path) {
    if (!path || !*path) {
        return false;
    }

    static const char *const tokens[] = {
        "/.bootstrapped",
        "/applications/cydia.app",
        "/applications/sileo.app",
        "/applications/zebra.app",
        "/applications/filza.app",
        "/bin/bash",
        "/bin/sh",
        "/etc/apt",
        "/library/mobilesubstrate",
        "/library/substrate",
        "/private/var/lib/apt",
        "/private/var/stash",
        "/procursus",
        "/usr/bin/cycript",
        "/usr/bin/ssh",
        "/usr/lib/libjailbreak",
        "/usr/lib/libsubstitute",
        "/usr/lib/libsubstrate",
        "/usr/lib/substrate",
        "/usr/lib/tweakinject",
        "/usr/sbin/frida-server",
        "/usr/sbin/sshd",
        "/var/jb",
        "/var/lib/apt",
        "/var/mobile/library/sbsettings",
        "/var/root",
        "/var/stash",
        "apt/sources.list",
        "cydia",
        "dopamine",
        "ellekit",
        "frida",
        "libhooker",
        "mobilesubstrate",
        "palera1n",
        "sileo",
        "substitute",
        "tweakinject",
        "unc0ver",
        "zebra",
    };

    for (size_t i = 0; i < sizeof(tokens) / sizeof(tokens[0]); i++) {
        if (sb_ascii_contains_ci(path, tokens[i])) {
            return true;
        }
    }

    return false;
}

static bool sb_is_app_writable_path(const char *path) {
    return sb_ascii_contains_ci(path, "/containers/data/application/") ||
           sb_ascii_contains_ci(path, "/soccerappbypasslogs/") ||
           sb_ascii_contains_ci(path, "/soccerappbypass/");
}

bool sb_should_deny_write_probe(const char *path) {
    if (!path || !*path || sb_is_app_writable_path(path)) {
        return false;
    }

    if (sb_is_sensitive_jb_path(path)) {
        return true;
    }

    bool suspicious_name = sb_ascii_contains_ci(path, "jailbreak") ||
                           sb_ascii_contains_ci(path, "jbprobe") ||
                           sb_ascii_contains_ci(path, ".installed_dopamine");
    if (!suspicious_name) {
        return false;
    }

    return sb_starts_with(path, "/private/") ||
           sb_starts_with(path, "/var/") ||
           sb_starts_with(path, "/usr/") ||
           sb_starts_with(path, "/tmp/");
}

bool sb_is_injection_image_name(const char *name) {
    if (!name || !*name) {
        return false;
    }

    static const char *const tokens[] = {
        "/var/jb/",
        "/procursus/",
        "/library/mobilesubstrate/",
        "ellekit",
        "frida",
        "libhooker",
        "libsubstrate",
        "mobilesubstrate",
        "soccerappbypass",
        "substitute",
        "tweakinject",
    };

    for (size_t i = 0; i < sizeof(tokens) / sizeof(tokens[0]); i++) {
        if (sb_ascii_contains_ci(name, tokens[i])) {
            return true;
        }
    }

    return false;
}

int sb_make_log_basename(unsigned long ident, const char *kind, char *out, size_t out_size) {
    if (!kind || !out || out_size == 0) {
        return -1;
    }

    const char *ext = strcmp(kind, "meta") == 0 ? "txt" : "bin";
    int needed = snprintf(out, out_size, "%06lu-%s.%s", ident, kind, ext);
    if (needed < 0 || (size_t)needed >= out_size) {
        return -1;
    }

    return 0;
}

static bool sb_metadata_version_is_plausible(unsigned int version) {
    return version >= 20 && version <= 40;
}

static bool sb_metadata_magic_is_supported(unsigned int magic) {
    return magic == SB_IL2CPP_METADATA_MAGIC || magic == 0;
}

size_t sb_metadata_size_from_header(const void *metadata, size_t readable_limit) {
    if (!metadata || readable_limit < 0x40) {
        return 0;
    }

    const unsigned int *words = (const unsigned int *)metadata;
    if (!sb_metadata_magic_is_supported(words[0]) || !sb_metadata_version_is_plausible(words[1])) {
        return 0;
    }

    size_t word_count = readable_limit / sizeof(unsigned int);
    size_t first_section_offset = 0;
    for (size_t i = 2; i + 1 < word_count && i < 96; i += 2) {
        unsigned int offset = words[i];
        unsigned int size = words[i + 1];
        if (offset >= 0x40 && offset < 0x10000 && size < 0x40000000u) {
            if (first_section_offset == 0 || offset < first_section_offset) {
                first_section_offset = offset;
            }
        }
    }

    if (first_section_offset < 0x40 || first_section_offset > readable_limit) {
        return 0;
    }

    size_t pair_count = (first_section_offset - 8) / 8;
    size_t max_end = first_section_offset;
    for (size_t pair = 0; pair < pair_count; pair++) {
        size_t i = 2 + pair * 2;
        if (i + 1 >= word_count) {
            break;
        }

        size_t offset = words[i];
        size_t size = words[i + 1];
        if (offset == 0 || size == 0 || offset > 0x40000000u || size > 0x40000000u) {
            continue;
        }

        size_t end = offset + size;
        if (end >= offset && end > max_end) {
            max_end = end;
        }
    }

    return max_end <= 0x40000000u ? max_end : 0;
}

bool sb_metadata_header_needs_magic_repair(const void *metadata, size_t readable_limit) {
    if (!metadata || readable_limit < 0x40) {
        return false;
    }

    const unsigned int *words = (const unsigned int *)metadata;
    return words[0] == 0 &&
           sb_metadata_version_is_plausible(words[1]) &&
           sb_metadata_size_from_header(metadata, readable_limit) > 0;
}

void sb_repair_metadata_magic(void *metadata, size_t metadata_size) {
    if (!metadata || metadata_size < 0x40) {
        return;
    }

    if (sb_metadata_header_needs_magic_repair(metadata, metadata_size)) {
        unsigned int *words = (unsigned int *)metadata;
        words[0] = SB_IL2CPP_METADATA_MAGIC;
    }
}

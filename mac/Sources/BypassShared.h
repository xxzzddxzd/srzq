#ifndef SOCCERAPP_BYPASS_SHARED_H
#define SOCCERAPP_BYPASS_SHARED_H

#include <stddef.h>
#include <stdbool.h>

bool sb_is_sensitive_jb_path(const char *path);
bool sb_should_deny_write_probe(const char *path);
bool sb_is_injection_image_name(const char *name);
int sb_make_log_basename(unsigned long ident, const char *kind, char *out, size_t out_size);
size_t sb_metadata_size_from_header(const void *metadata, size_t readable_limit);
bool sb_metadata_header_needs_magic_repair(const void *metadata, size_t readable_limit);
void sb_repair_metadata_magic(void *metadata, size_t metadata_size);

#endif

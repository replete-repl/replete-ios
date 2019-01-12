#include "ufile.h"

UFILE* u_fopen(const char *filename, const char *perm, const char *locale, const char *codepage) {
    return fopen(filename, perm);
}

int32_t u_file_write(const UChar *ustring, int32_t count, UFILE *f) {
    return (int32_t) fwrite(ustring, sizeof(UChar), count, f);
}

int32_t u_file_read(UChar *chars, int32_t count, UFILE *f) {
    return (int32_t)fread(chars, sizeof(UChar), count, f);
}

int u_feof(UFILE* f) {
    return feof(f);
}

void u_fflush(UFILE* f) {
    fflush(f);
}

FILE* u_fgetfile (UFILE* f) {
    return f;
}

void u_fclose(UFILE* f) {
    fclose(f);
}

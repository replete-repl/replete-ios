#include <stdio.h>
#include <iconv.h>

typedef struct {
    FILE* fp;
    iconv_t cd;
} UFILE;

#define UChar uint16_t

UFILE* u_fopen(const char *filename, const char *perm, const char *locale, const char *codepage);

int32_t u_file_write(const UChar *ustring, int32_t count, UFILE *f);

int32_t u_file_read(UChar *chars, int32_t count, UFILE *f);

int u_feof(UFILE* f);

void u_fflush(UFILE* f);

FILE* u_fgetfile (UFILE* f);

void u_fclose(UFILE* f);

/* LD_PRELOAD shim for FreeRDP: dump every pointer (cursor) the client receives,
 * then call the real conversion. Output: $PTR_DUMP_DIR/ptr-<n>.bin with header
 * "w h xorBpp xorLen andLen\n" followed by the raw XOR and AND mask bytes. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

typedef int (*copy_fn)(uint8_t *, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
                       const uint8_t *, uint32_t, const uint8_t *, uint32_t, uint32_t, const void *);

int
freerdp_image_copy_from_pointer_data(uint8_t *dst, uint32_t fmt, uint32_t step, uint32_t x, uint32_t y,
                                     uint32_t w, uint32_t h, const uint8_t *xor_mask, uint32_t xor_len,
                                     const uint8_t *and_mask, uint32_t and_len, uint32_t xor_bpp,
                                     const void *palette)
{
    static int n;
    static copy_fn real;
    const char *dir = getenv("PTR_DUMP_DIR");
    char path[512];
    FILE *f;

    if (real == NULL)
    {
        real = (copy_fn) dlsym(RTLD_NEXT, "freerdp_image_copy_from_pointer_data");
    }
    if (dir != NULL)
    {
        snprintf(path, sizeof(path), "%s/ptr-%03d.bin", dir, n++);
        f = fopen(path, "wb");
        if (f != NULL)
        {
            fprintf(f, "%u %u %u %u %u\n", w, h, xor_bpp, xor_len, and_len);
            if (xor_mask != NULL && xor_len > 0) fwrite(xor_mask, 1, xor_len, f);
            if (and_mask != NULL && and_len > 0) fwrite(and_mask, 1, and_len, f);
            fclose(f);
        }
    }
    return real(dst, fmt, step, x, y, w, h, xor_mask, xor_len, and_mask, and_len, xor_bpp, palette);
}

/* Generated FFI header for osp_core */
#ifndef OSP_CORE_H
#define OSP_CORE_H

#include <stdint.h>

/* Opaque handle to Core instance */
typedef struct CoreHandle CoreHandle;

/* C-compatible Item structure */
typedef struct {
    int64_t id;
    int32_t kind;           /* 0=Text, 1=Rtf, 2=Image, 3=File */
    char *content_ref;
    char *source_app;       /* NULL if None */
    int64_t created_at;
    int32_t pinned;         /* 0=false, 1=true */
    char *tags_json;        /* JSON array as string */
} CItem;

/* C-compatible array of items */
typedef struct {
    CItem *items;
    size_t count;
} CItemArray;

/* Core management */
CoreHandle *core_new(const char *db_path, const char *blobs_dir);
void core_free(CoreHandle *handle);

/* Item operations */
int64_t core_add_item(CoreHandle *handle, int32_t kind, const char *content_ref, 
                      const char *source_app, int64_t created_at);
int64_t core_dedupe_insert(CoreHandle *handle, int32_t kind, const char *content_ref,
                           const char *source_app, int64_t created_at);
CItemArray *core_search(CoreHandle *handle, const char *query, uint32_t limit);
CItem *core_get_item(CoreHandle *handle, int64_t id);
int32_t core_delete_item(CoreHandle *handle, int64_t id);
int32_t core_pin_item(CoreHandle *handle, int64_t id, int32_t pinned);

/* Memory management */
void item_free(CItem *item);
void item_array_free(CItemArray *array);
void string_free(char *s);

#endif /* OSP_CORE_H */

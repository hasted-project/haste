//! FFI (Foreign Function Interface) layer for Swift/C interop.
//!
//! This module provides a C-compatible API that can be called from Swift.
//! All functions are marked `extern "C"` and use C-compatible types.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_longlong};
use std::path::Path;
use std::ptr;

use crate::{Core, Item, ItemKind, NewItem};

/// Opaque pointer to Core instance (passed to Swift as OpaquePointer)
pub struct CoreHandle {
    core: Core,
}

/// C-compatible Item structure
#[repr(C)]
pub struct CItem {
    pub id: c_longlong,
    pub kind: c_int, // 0=Text, 1=Rtf, 2=Image, 3=File
    pub content_ref: *mut c_char,
    pub source_app: *mut c_char, // NULL if None
    pub created_at: c_longlong,
    pub pinned: c_int, // 0=false, 1=true
    pub tags_json: *mut c_char, // JSON array as string
}

/// C-compatible array of items
#[repr(C)]
pub struct CItemArray {
    pub items: *mut CItem,
    pub count: usize,
}

/// Create a new Core instance
///
/// # Safety
/// - db_path and blobs_dir must be valid UTF-8 null-terminated strings
/// - Caller must call core_free() when done
#[no_mangle]
pub unsafe extern "C" fn core_new(
    db_path: *const c_char,
    blobs_dir: *const c_char,
) -> *mut CoreHandle {
    if db_path.is_null() || blobs_dir.is_null() {
        return ptr::null_mut();
    }

    let db_path_str = match CStr::from_ptr(db_path).to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    let blobs_dir_str = match CStr::from_ptr(blobs_dir).to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    match Core::open(Path::new(db_path_str), Path::new(blobs_dir_str)) {
        Ok(core) => Box::into_raw(Box::new(CoreHandle { core })),
        Err(_) => ptr::null_mut(),
    }
}

/// Free a Core instance
///
/// # Safety
/// - handle must be a valid pointer returned by core_new()
/// - Must not be called twice on the same pointer
#[no_mangle]
pub unsafe extern "C" fn core_free(handle: *mut CoreHandle) {
    if !handle.is_null() {
        let _ = Box::from_raw(handle);
    }
}

/// Add a new item to the clipboard
///
/// # Safety
/// - handle must be valid
/// - content_ref must be valid UTF-8 null-terminated string
/// - source_app can be NULL
/// - Returns item ID on success, -1 on error
#[no_mangle]
pub unsafe extern "C" fn core_add_item(
    handle: *mut CoreHandle,
    kind: c_int,
    content_ref: *const c_char,
    source_app: *const c_char,
    created_at: c_longlong,
) -> c_longlong {
    if handle.is_null() || content_ref.is_null() {
        return -1;
    }

    let handle = &*handle;

    let content_ref_str = match CStr::from_ptr(content_ref).to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let source_app_opt = if source_app.is_null() {
        None
    } else {
        CStr::from_ptr(source_app).to_str().ok().map(|s| s.to_string())
    };

    let item_kind = match kind {
        0 => ItemKind::Text,
        1 => ItemKind::Rtf,
        2 => ItemKind::Image,
        3 => ItemKind::File,
        _ => return -1,
    };

    let new_item = NewItem {
        kind: item_kind,
        content_ref: content_ref_str.to_string(),
        source_app: source_app_opt,
        created_at,
        tags: vec![],
    };

    match handle.core.add_item(new_item) {
        Ok(id) => id,
        Err(_) => -1,
    }
}

/// Add item with deduplication
///
/// Returns item ID if inserted, 0 if duplicate detected, -1 on error
#[no_mangle]
pub unsafe extern "C" fn core_dedupe_insert(
    handle: *mut CoreHandle,
    kind: c_int,
    content_ref: *const c_char,
    source_app: *const c_char,
    created_at: c_longlong,
) -> c_longlong {
    if handle.is_null() || content_ref.is_null() {
        return -1;
    }

    let handle = &*handle;

    let content_ref_str = match CStr::from_ptr(content_ref).to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let source_app_opt = if source_app.is_null() {
        None
    } else {
        CStr::from_ptr(source_app).to_str().ok().map(|s| s.to_string())
    };

    let item_kind = match kind {
        0 => ItemKind::Text,
        1 => ItemKind::Rtf,
        2 => ItemKind::Image,
        3 => ItemKind::File,
        _ => return -1,
    };

    let new_item = NewItem {
        kind: item_kind,
        content_ref: content_ref_str.to_string(),
        source_app: source_app_opt,
        created_at,
        tags: vec![],
    };

    match handle.core.dedupe_insert(new_item) {
        Ok(Some(id)) => id,
        Ok(None) => 0, // Duplicate
        Err(_) => -1,
    }
}

/// Search for items
///
/// # Safety
/// - handle must be valid
/// - query must be valid UTF-8 null-terminated string
/// - Caller must call item_array_free() on the returned array
#[no_mangle]
pub unsafe extern "C" fn core_search(
    handle: *mut CoreHandle,
    query: *const c_char,
    limit: u32,
) -> *mut CItemArray {
    if handle.is_null() || query.is_null() {
        return ptr::null_mut();
    }

    let handle = &*handle;

    let query_str = match CStr::from_ptr(query).to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    let items = match handle.core.search(query_str, limit) {
        Ok(items) => items,
        Err(_) => return ptr::null_mut(),
    };

    items_to_c_array(items)
}

/// Get a single item by ID
///
/// # Safety
/// - handle must be valid
/// - Caller must call item_free() on the returned item
#[no_mangle]
pub unsafe extern "C" fn core_get_item(
    handle: *mut CoreHandle,
    id: c_longlong,
) -> *mut CItem {
    if handle.is_null() {
        return ptr::null_mut();
    }

    let handle = &*handle;

    match handle.core.get(id) {
        Ok(item) => item_to_c(item),
        Err(_) => ptr::null_mut(),
    }
}

/// Delete an item
///
/// Returns 0 on success, -1 on error
#[no_mangle]
pub unsafe extern "C" fn core_delete_item(
    handle: *mut CoreHandle,
    id: c_longlong,
) -> c_int {
    if handle.is_null() {
        return -1;
    }

    let handle = &*handle;

    match handle.core.delete(id) {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Pin or unpin an item
///
/// Returns 0 on success, -1 on error
#[no_mangle]
pub unsafe extern "C" fn core_pin_item(
    handle: *mut CoreHandle,
    id: c_longlong,
    pinned: c_int,
) -> c_int {
    if handle.is_null() {
        return -1;
    }

    let handle = &*handle;

    match handle.core.pin(id, pinned != 0) {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Free a single CItem
///
/// # Safety
/// - item must be a valid pointer returned by core_get_item()
#[no_mangle]
pub unsafe extern "C" fn item_free(item: *mut CItem) {
    if item.is_null() {
        return;
    }

    let item = Box::from_raw(item);
    if !item.content_ref.is_null() {
        let _ = CString::from_raw(item.content_ref);
    }
    if !item.source_app.is_null() {
        let _ = CString::from_raw(item.source_app);
    }
    if !item.tags_json.is_null() {
        let _ = CString::from_raw(item.tags_json);
    }
}

/// Free a CItemArray
///
/// # Safety
/// - array must be a valid pointer returned by core_search()
#[no_mangle]
pub unsafe extern "C" fn item_array_free(array: *mut CItemArray) {
    if array.is_null() {
        return;
    }

    let array = Box::from_raw(array);
    if !array.items.is_null() {
        let items = Vec::from_raw_parts(array.items, array.count, array.count);
        for item in items {
            if !item.content_ref.is_null() {
                let _ = CString::from_raw(item.content_ref);
            }
            if !item.source_app.is_null() {
                let _ = CString::from_raw(item.source_app);
            }
            if !item.tags_json.is_null() {
                let _ = CString::from_raw(item.tags_json);
            }
        }
    }
}

// Helper functions

unsafe fn item_to_c(item: Item) -> *mut CItem {
    let content_ref = match CString::new(item.content_ref) {
        Ok(s) => s.into_raw(),
        Err(_) => return ptr::null_mut(),
    };

    let source_app = match item.source_app {
        Some(app) => match CString::new(app) {
            Ok(s) => s.into_raw(),
            Err(_) => ptr::null_mut(),
        },
        None => ptr::null_mut(),
    };

    let tags_json = match serde_json::to_string(&item.tags) {
        Ok(json) => match CString::new(json) {
            Ok(s) => s.into_raw(),
            Err(_) => ptr::null_mut(),
        },
        Err(_) => ptr::null_mut(),
    };

    let kind = match item.kind {
        ItemKind::Text => 0,
        ItemKind::Rtf => 1,
        ItemKind::Image => 2,
        ItemKind::File => 3,
    };

    Box::into_raw(Box::new(CItem {
        id: item.id,
        kind,
        content_ref,
        source_app,
        created_at: item.created_at,
        pinned: if item.pinned { 1 } else { 0 },
        tags_json,
    }))
}

unsafe fn items_to_c_array(items: Vec<Item>) -> *mut CItemArray {
    let mut c_items = Vec::with_capacity(items.len());

    for item in items {
        let content_ref = match CString::new(item.content_ref) {
            Ok(s) => s.into_raw(),
            Err(_) => continue,
        };

        let source_app = match item.source_app {
            Some(app) => match CString::new(app) {
                Ok(s) => s.into_raw(),
                Err(_) => ptr::null_mut(),
            },
            None => ptr::null_mut(),
        };

        let tags_json = match serde_json::to_string(&item.tags) {
            Ok(json) => match CString::new(json) {
                Ok(s) => s.into_raw(),
                Err(_) => ptr::null_mut(),
            },
            Err(_) => ptr::null_mut(),
        };

        let kind = match item.kind {
            ItemKind::Text => 0,
            ItemKind::Rtf => 1,
            ItemKind::Image => 2,
            ItemKind::File => 3,
        };

        c_items.push(CItem {
            id: item.id,
            kind,
            content_ref,
            source_app,
            created_at: item.created_at,
            pinned: if item.pinned { 1 } else { 0 },
            tags_json,
        });
    }

    let count = c_items.len();
    let items_ptr = c_items.as_mut_ptr();
    std::mem::forget(c_items);

    Box::into_raw(Box::new(CItemArray {
        items: items_ptr,
        count,
    }))
}


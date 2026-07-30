#pragma once
#include <cstdint>

// ============================================================
// Class type info addresses (relative to il2cpp base)
// From: dump.cs / script.json
// ============================================================
namespace ClassAddr {
    inline constexpr uintptr_t BipedMap              = 0xAC5E530;
    inline constexpr uintptr_t GEADDDBFAGHCHFF       = 0xAC62738;
    inline constexpr uintptr_t PhotonPlayer           = 0xAC65AE8;
    inline constexpr uintptr_t PhotonView             = 0xAC65B58;
    inline constexpr uintptr_t PlayerController       = 0xAC60F58;
    inline constexpr uintptr_t PlayerMainCamera       = 0xAC60F08;
    inline constexpr uintptr_t PlayerManager          = 0xAC60F30;
    inline constexpr uintptr_t Room                   = 0xAC63278;
    inline constexpr uintptr_t RoomInfo               = 0xAC63280;
    inline constexpr uintptr_t GameController         = 0xAC44100; // approximate
}

// ============================================================
// Il2CppClass struct offset for static_fields pointer (v24.x)
// ============================================================
#define OFFSET_CLASS_STATIC_FIELDS  0xB8

// ============================================================
// Helper macros to resolve a static field value at runtime.
// Usage: uint64_t cam = RESOLVE_STATIC(il2cppBase, PlayerMainCamera, 0);
// ============================================================
#define RESOLVE_CLASS(base, className) \
    ((uint64_t*)((base) + ClassAddr::className))

#define RESOLVE_STATIC_FIELDS(base, className) \
    (*(uint64_t*)(RESOLVE_CLASS(base, className) + OFFSET_CLASS_STATIC_FIELDS))

#define RESOLVE_STATIC(base, className, fieldIndex) \
    (*(uint64_t*)(RESOLVE_STATIC_FIELDS(base, className) + ((fieldIndex) * 8)))

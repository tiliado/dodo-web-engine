namespace Wevf.Keyboard {

public static uint serialize_modifiers(Gdk.ModifierType modifiers) {
    uint val = 0;
    if ((modifiers & Gdk.ModifierType.SHIFT_MASK) != 0) {
        val += 1 << 0;
    }
    if ((modifiers & Gdk.ModifierType.CONTROL_MASK) != 0) {
        val += 1 << 1;
    }
    if ((modifiers & Gdk.ModifierType.MOD1_MASK) != 0) {
        val += 1 << 2;
    }
    if ((modifiers & Gdk.ModifierType.META_MASK) != 0) {
        val += 1 << 3;
    }
    return val;
}

} // namespace Wevf.Keyboard

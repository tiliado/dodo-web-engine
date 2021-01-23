using GL;

namespace Dodo.Textures {

public GLuint load_from_pixels(void* data, uint fmt, int width, int height, int stride) {
    // FIXME: fmt & stride
    GLuint gl_textures[1];
    glGenTextures(1, gl_textures);
    GLuint texture = gl_textures[0];
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, data);
    return texture;
}

} // namespace Dodo.Textures

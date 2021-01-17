using GL;

namespace Wevf {

public errordomain Error {
    FOO,
    VERTEX_SHADER,
    FRAGMENT_SHADER,
    PROGRAM;
}


const string RECT_VERTEX_SHADER = """
#version 300 es
layout (location = 0) in vec2 in_pos_2d;
layout (location = 1) in vec2 in_texture_coordinates;
out vec2 texture_coordinates;

void main()
{
    gl_Position = vec4(in_pos_2d, 0.0, 1.0);
    texture_coordinates = in_texture_coordinates;
}
""";

const string RECT_FRAGMENT_SHADER = """
#version 300 es
precision mediump float;
in vec2 texture_coordinates;
uniform sampler2D texture_unit;
out vec4 FragColor;

void main()
{
    FragColor = texture(texture_unit, texture_coordinates);
}
""";


public class Canvas : Gtk.GLArea {
    private const int ICON_SIZE = 256;
    public uint frames_per_second {get; private set; default = 0;}
    private GLuint gl_program = 0;
    private GLuint gl_element_buffer = 0;
    private GLuint gl_vertex_buffer = 0;
    private GLuint gl_vertex_array = 0;
    private GLuint gl_texture_loading_icon = 0;
    private GLuint gl_texture_crashed_icon = 0;
    private int width = 0;
    private int height = 0;
    private Surface? surface;
    private uint frames = 0;
    private bool crashed = false;
    private uint tick_callback_id = 0;
    private uint frames_per_second_callback_id = 0;

    public Gdk.RGBA background_color {
        get; set; default = Gdk.RGBA() {red = 0.1, green = 0.1, blue = 0.1, alpha = 1.0};
    }

    public Canvas() {
        realize.connect(on_realize);
        unrealize.connect(on_unrealize);
        set_auto_render(true);
    }

    ~Canvas() {
        if (this.surface != null) {
            this.surface.state_committed.disconnect(on_surface_committed);
            this.surface.set_gl_context(null);
        }

        if (tick_callback_id != 0) {
            remove_tick_callback(tick_callback_id);
            Source.remove(frames_per_second_callback_id);
        }
    }

    public void set_surface(Surface? surface) {
        if (this.surface != null) {
            this.surface.state_committed.disconnect(on_surface_committed);
            this.surface.set_gl_context(null);
        }

        this.surface = surface;

        if (surface != null) {
            if (get_realized()) {
                surface.set_gl_context(this.context);
            }

            surface.state_committed.connect(on_surface_committed);

            if (tick_callback_id == 0) {
                tick_callback_id = add_tick_callback(tick_callback);
                frames_per_second = frames = 0;
                frames_per_second_callback_id = Timeout.add(1000, frames_per_second_callback);
            }
        } else if (tick_callback_id != 0) {
            remove_tick_callback(tick_callback_id);
            tick_callback_id = 0;
            Source.remove(frames_per_second_callback_id);
            frames_per_second_callback_id = 0;
            frames_per_second = frames = 0;
        }
    }

    private bool frames_per_second_callback() {
        frames_per_second = frames;
        frames = 0;
        return Source.CONTINUE;
    }

    private bool tick_callback() {
        if (surface != null) {
            surface.queue_render_frame();
        }
        return Source.CONTINUE;
    }

    public override bool render(Gdk.GLContext ctx) {

        if (surface != null && surface.buffer != null) {
            crashed = true;
            draw_texture(surface.buffer.get_texture(), surface.buffer.width, surface.buffer.height);
            frames++;
        } else {
            draw_texture(0, 0, 0);
        }
        return true; // true = stop, false = continue
    }

    public override void resize(int width, int height) {
        debug("Resize: %d×%d", width, height);
        this.width = width;
        this.height = height;
    }

    private void on_realize() {
        make_current();
        if (get_error() != null) {
            return;
        }

        try {
            init_gl();
        } catch (GLib.Error e) {
            warning("Failure: %s", e.message);
            free_gl();
            set_error(e);
        }
    }

    private void on_unrealize() {
        make_current();
        if (get_error() != null) {
            return;
        }

        free_gl();
    }

    private void init_gl() throws Error {
        // Many thanks to https://learnopengl.com/Getting-started/Hello-Triangle
        GLubyte info_log[1024];
        GL.GLsizei length[1];
        GLint status[1];

        // Vertex shader
        GLuint gl_vertex_shader = glCreateShader(GL_VERTEX_SHADER);
        (unowned string)[] source = {RECT_VERTEX_SHADER};
        glShaderSource(gl_vertex_shader, 1, source, null);
        glCompileShader(gl_vertex_shader);
        glGetShaderiv(gl_vertex_shader, GL_COMPILE_STATUS, status);

        if (status[0] == 0) {
            glGetShaderInfoLog(gl_vertex_shader, 1024, length, info_log);
            glDeleteShader(gl_vertex_shader);
            throw new Error.VERTEX_SHADER(
                "Failed to compile vertex shader: %s",
                (string) info_log
            );
        }

        // Fragment shader
        GLuint gl_fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
        source[0] = RECT_FRAGMENT_SHADER;
        glShaderSource(gl_fragment_shader, 1, source, null);
        glCompileShader(gl_fragment_shader);
        glGetShaderiv(gl_fragment_shader, GL_COMPILE_STATUS, status);

        if (status[0] == 0) {
            glGetShaderInfoLog(gl_fragment_shader, 1024, length, info_log);
            glDeleteShader(gl_vertex_shader);
            glDeleteShader(gl_fragment_shader);
            throw new Error.FRAGMENT_SHADER(
                "Failed to compile fragment shader: %s",
                (string) info_log
            );
        }

        gl_program = glCreateProgram();
        glAttachShader(gl_program, gl_fragment_shader);
        glAttachShader(gl_program, gl_vertex_shader);
        glLinkProgram(gl_program);
        glDeleteShader(gl_vertex_shader);
        glDeleteShader(gl_fragment_shader);


        glGetProgramiv(gl_program, GL_LINK_STATUS, status);
        if (status[0] == 0) {
            glGetProgramInfoLog(gl_program, 1024, length, info_log);
            throw new Error.PROGRAM(
                "Failed to link program: %s",
                (string) info_log
            );
        }

        // Allocate objects
        GLuint gl_vertex_arrays[1];
        glGenVertexArrays(1, gl_vertex_arrays);
        GLuint gl_buffers[2];
        glGenBuffers(2, gl_buffers);

        // Vertex array object (VAO)
        gl_vertex_array = gl_vertex_arrays[0];
        glBindVertexArray(gl_vertex_array);

        // Vertex buffer object (VBO)
        gl_vertex_buffer = gl_buffers[0];
        glBindBuffer(GL_ARRAY_BUFFER, gl_vertex_buffer);
        float[] rect_vertices = {
            // positions[2] + texture coordinates[2]
            1.0f, 1.0f, 1.0f, 1.0f, // top right
            1.0f, -1.0f, 1.0f, 0.0f, // bottom right
            -1.0f, -1.0f, 0.0f, 0.0f, // bottom left
            -1.0f, 1.0f, 0.0f, 1.0f, // top left
        };
        glBufferData(GL_ARRAY_BUFFER, (GLsizei) (rect_vertices.length * sizeof(float)), (GLvoid[]) rect_vertices, GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(
            0, // location for pos_2d
            2, // size - x & y coordinates
            GL_FLOAT, // type
            (GLboolean) GL_FALSE, // do not normalize
            (GLsizei) (4 * sizeof(float)), // distance between neighbors
            (void*) 0 // offset of the first item
        );

        glEnableVertexAttribArray(1);
        glVertexAttribPointer(
            1, // location for texture_coordinates
            2, // size - x & y coordinates
            GL_FLOAT, // type
            (GLboolean) GL_FALSE, // do not normalize
            (GLsizei) (4 * sizeof(float)), // distance between neighbors
            (void*) (2 * sizeof(float))  // offset of the first item
        );

        // Element buffer object (EBO)
        int[] rect_indices = {
            0, 1, 2, // first triangle
            0, 2, 3, // second triangle
        };
        gl_element_buffer = gl_buffers[1];
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_element_buffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizei) (rect_indices.length * sizeof(int)), (GLvoid[]) rect_indices, GL_STATIC_DRAW);

        Gtk.IconTheme icons = Gtk.IconTheme.get_default();
        try {
            Gdk.Pixbuf? icon = icons.load_icon("image-loading", ICON_SIZE, 0);
            if (!icon.get_has_alpha()) {
                icon = icon.add_alpha(false, 0, 0, 0);
            }
            void* data = (void*) icon.read_pixels();
            gl_texture_loading_icon = Textures.load_from_pixels(data, 0, icon.width, icon.height, icon.width * 4);

            icon = icons.load_icon("face-sick-symbolic", ICON_SIZE, 0);
            if (!icon.get_has_alpha()) {
                icon = icon.add_alpha(false, 0, 0, 0);
            }
            data = (void*) icon.read_pixels();
            gl_texture_crashed_icon = Textures.load_from_pixels(data, 0, icon.width, icon.height, icon.width * 4);
        } catch (GLib.Error e) {
            warning("Cannot load icon: %s", e.message);
        }

        // Finish
        glUseProgram(0);
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

        if (surface != null) {
            surface.set_gl_context(this.context);
        }
    }

    private void free_gl() {
        if (surface != null) {
            surface.set_gl_context(null);
        }

        if (gl_texture_loading_icon != 0) {
            glDeleteTextures(1, {gl_texture_loading_icon});
        }

        if (gl_texture_crashed_icon != 0) {
            glDeleteTextures(1, {gl_texture_crashed_icon});
        }

        glBindVertexArray(0);
        glUseProgram(0);

        if (gl_vertex_array != 0) {
            glDeleteVertexArrays(1, {gl_vertex_array});
            gl_vertex_array = 0;
        }
        if (gl_vertex_buffer != 0) {
            glDeleteBuffers(1, {gl_vertex_buffer});
            gl_vertex_buffer = 0;
        }
        if (gl_element_buffer != 0) {
            glDeleteBuffers(1, {gl_element_buffer});
            gl_element_buffer = 0;
        }
        if (gl_program != 0) {
            glDeleteProgram(gl_program);
            gl_program = 0;
        }
    }

    private void draw_texture(GLuint texture_id, int width, int height) {
        glClearColor(
            (GLfloat) background_color.red,
            (GLfloat) background_color.green,
            (GLfloat) background_color.blue,
            (GLfloat) background_color.alpha
        );
        glClear(GL_COLOR_BUFFER_BIT);

        if (texture_id == 0) {
            texture_id = crashed ? gl_texture_crashed_icon : gl_texture_loading_icon;
            width = ICON_SIZE;
            height = ICON_SIZE;
        } else {
            if (width <= 0) {
                width = this.width;
            }
            if (height <= 0) {
                height = this.height;
            }
        }

        // Center viewport
        glViewport((this.width - width) / 2, (this.height - height) / 2, width, height);

        if (texture_id != 0) {
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            glUseProgram(gl_program);
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, texture_id);
            GLint texture_location = glGetUniformLocation(gl_program, "texture_unit");
            glUniform1i(texture_location, 1);
            glBindVertexArray(gl_vertex_array);
            glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, (void*) 0);
            glUseProgram(0);
            glBindVertexArray(0);
        }
    }

    private void on_surface_committed(Surface surface) {
        queue_render();
    }
}

} // namespace Nuvola

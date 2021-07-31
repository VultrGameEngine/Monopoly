#shader vertex
#version 330 core
#extension GL_ARB_separate_shader_objects: enable

layout (location = 0) in vec3 v_Position;
layout (location = 1) in vec3 v_Normal;
layout (location = 2) in vec2 v_UV;

out vec3 f_Normal;
out vec3 f_Position;
out vec2 f_UV;

layout (std140) uniform Camera {
    vec4 position;
    mat4 view_matrix;
    mat4 projection_matrix;
} ub_Camera;

uniform mat4 u_MVP;
uniform mat4 u_Model_matrix;

void main() 
{
    gl_Position = u_MVP * vec4(v_Position, 1.0f);
    f_Position  = vec3(u_Model_matrix * vec4(v_Position, 1.0f));
    f_Normal  	= mat3(transpose(inverse(u_Model_matrix))) * v_Normal;
    f_UV 	= v_UV;
}

#shader fragment
#version 330 core
#extension GL_ARB_separate_shader_objects: enable

out vec4 color;

in vec3 f_Position;
in vec3 f_Normal;
in vec2 f_UV;

layout (std140) uniform Camera {
    vec4 position;
    mat4 view_matrix;
    mat4 projection_matrix;
} ub_Camera;

struct DirectionalLight {
  vec3 direction;

  vec3 ambient;
  vec3 diffuse;
  float specular;
};

struct PointLight {
  vec3 position;

  float constant;
  float linear;
  float quadratic;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

uniform vec4 u_Tint;

uniform sampler2D u_Diffuse;
uniform sampler2D u_Specular;
uniform float u_Shininess;

// TODO: Remove this
uniform vec3 light_position;

uniform DirectionalLight u_Directional_light;
uniform mat3 u_Normal_matrix;

void main()
{    
    vec3 ambient = u_Directional_light.ambient * u_Directional_light.diffuse * vec3(texture(u_Diffuse, f_UV));

    vec3 normal = normalize(u_Normal_matrix * f_Normal);
    vec3 light_direction = normalize(light_position - f_Position);

    float diffuse_impact = max(dot(normal, light_direction), 0.0);
    vec3 diffuse = diffuse_impact * u_Directional_light.diffuse * vec3(texture(u_Diffuse, f_UV));

    vec3 view_direction = normalize(ub_Camera.position.xyz - f_Position);
    vec3 reflect_direction = reflect(-light_direction, normal);

    float spec = pow(max(dot(view_direction, reflect_direction), 0.0), u_Shininess);
    vec3 specular = u_Directional_light.specular * spec * u_Directional_light.diffuse * vec3(texture(u_Specular, f_UV));
    
    vec3 result = (ambient + diffuse + specular) * u_Tint.xyz;
    color = vec4(result, 1.0f);
}

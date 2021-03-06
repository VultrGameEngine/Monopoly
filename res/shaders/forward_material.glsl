#shader vertex
#version 330 core
#extension GL_ARB_separate_shader_objects: enable

layout (location = 0) in vec3 v_Position;
layout (location = 1) in vec3 v_Normal;
layout (location = 2) in vec2 v_UV;
layout (location = 3) in vec3 v_Tangent;
layout (location = 4) in vec3 v_Bitangent;

out vec3 f_Normal;
out vec3 f_Position;
out vec2 f_UV;
out mat3 f_TBN;

layout (std140) uniform Camera {
    vec4 position;
    mat4 view_matrix;
    mat4 projection_matrix;
} ub_Camera;

uniform mat4 u_MVP;
uniform mat4 u_Model_matrix;
uniform mat3 u_Normal_matrix;

void main() 
{
    gl_Position = u_MVP * vec4(v_Position, 1.0f);
    f_Position  = vec3(u_Model_matrix * vec4(v_Position, 1.0f));
    f_Normal  	= v_Normal;
    f_UV 	= v_UV;


    // TBN matrix calculation
    vec3 T = normalize(u_Normal_matrix * v_Tangent);
    vec3 N = normalize(u_Normal_matrix * v_Normal);
    // Re-orthogonalize T with respect to N
    T = normalize(T - dot(T, N) * N);

    vec3 B = cross(N, T);

    f_TBN = mat3(T, B, N);
}

#shader fragment
#version 330 core
#extension GL_ARB_separate_shader_objects: enable

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 bright_color;

in vec3 f_Position;
in vec3 f_Normal;
in vec2 f_UV;
in mat3 f_TBN;

layout (std140) uniform Camera {
    vec4 position;
    mat4 view_matrix;
    mat4 projection_matrix;
} ub_Camera;

layout (std140) uniform DirectionalLight {
  vec4 direction;

  vec4 ambient;
  vec4 diffuse;
  float specular;
  float intensity;
  int exists;
} ub_Directional_light;

struct PointLight {
  vec3 position;

  float constant;
  float linear;
  float quadratic;

  vec3 ambient;
  vec3 diffuse;
  float specular;
  float intensity;
};

#define MAX_POINT_LIGHTS 256
layout (std140) uniform PointLights {
  vec4 positions[MAX_POINT_LIGHTS];

  vec4 constants[MAX_POINT_LIGHTS];
  vec4 linears[MAX_POINT_LIGHTS];
  vec4 quadratics[MAX_POINT_LIGHTS];

  vec4 ambients[MAX_POINT_LIGHTS];
  vec4 diffuses[MAX_POINT_LIGHTS];
  vec4 speculars[MAX_POINT_LIGHTS];
  vec4 intensities[MAX_POINT_LIGHTS];

  int count;
} ub_Point_lights;

uniform vec4 u_Tint;

uniform sampler2D u_Diffuse;

uniform int u_Has_specular_map = 0;
uniform sampler2D u_Specular;

uniform int u_Has_normal_map;
uniform sampler2D u_Normal;

uniform float u_Shininess;

uniform mat3 u_Normal_matrix;

vec3 calc_point_light(PointLight light, vec3 normal, vec3 view_direction, vec3 material_diffuse, vec3 material_specular);
vec3 calc_directional_light(vec3 normal, vec3 view_direction, vec3 material_diffuse, vec3 material_specular);

void main()
{    
    vec3 normal;
    if(u_Has_normal_map == 0) 
    {
	normal = normalize(u_Normal_matrix * f_Normal);
    }
    else
    {
	// Get normal from normal map in range [0, 1]
	normal = texture(u_Normal, f_UV).rgb;

	// Map this normal to a range [-1, 1]
	normal = normal * 2.0 - 1.0;

	normal = normalize(f_TBN * normal);
    }

    vec3 view_direction = normalize(ub_Camera.position.xyz - f_Position);

    vec3 material_diffuse = vec3(texture(u_Diffuse, f_UV));
    vec3 material_specular = u_Has_specular_map == 1 ? vec3(texture(u_Specular, f_UV)) : vec3(0.1);

    vec3 result = calc_directional_light(normal, view_direction, material_diffuse, material_specular);

    for(int i = 0; i < ub_Point_lights.count; i++) 
    {
	PointLight point_light = PointLight(ub_Point_lights.positions[i].xyz,
					    ub_Point_lights.constants[i].x,
					    ub_Point_lights.linears[i].x,
					    ub_Point_lights.quadratics[i].x,
					    ub_Point_lights.ambients[i].xyz,
					    ub_Point_lights.diffuses[i].xyz,
					    ub_Point_lights.speculars[i].x,
					    ub_Point_lights.intensities[i].x);

	result += calc_point_light(point_light, normal, view_direction, material_diffuse, material_specular);
    }

    result *= u_Tint.xyz;
    color = vec4(result, 1.0f);

    // Bloom
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    if(brightness > 1.0)
        bright_color = vec4(color.rgb, 1.0);
    else
        bright_color = vec4(0.0, 0.0, 0.0, 1.0);
}

vec3 calc_directional_light(vec3 normal, vec3 view_direction, vec3 material_diffuse, vec3 material_specular) 
{ 
    if(ub_Directional_light.exists == 0) 
	return vec3(0);
    vec3 ambient = ub_Directional_light.ambient.xyz * ub_Directional_light.diffuse.xyz * material_diffuse;

    vec3 light_direction = normalize(-ub_Directional_light.direction.xyz);

    float diffuse_impact = max(dot(normal, light_direction), 0.0);
    vec3 diffuse = diffuse_impact * ub_Directional_light.diffuse.xyz * material_diffuse;

    vec3 reflect_direction = reflect(-light_direction, normal);

    float spec = pow(max(dot(view_direction, reflect_direction), 0.0), u_Shininess);
    vec3 specular = ub_Directional_light.specular * spec * ub_Directional_light.diffuse.xyz * material_specular;

    return (ambient + diffuse + specular) * ub_Directional_light.intensity;
}

vec3 calc_point_light(PointLight light, vec3 normal, vec3 view_direction, vec3 material_diffuse, vec3 material_specular) 
{
    vec3 ambient = light.ambient.xyz * light.diffuse.xyz * material_diffuse;

    vec3 light_direction = normalize(light.position.xyz - f_Position);

    float diffuse_impact = max(dot(normal, light_direction), 0.0);
    vec3 diffuse = diffuse_impact * light.diffuse.xyz * material_diffuse;

    vec3 reflect_direction = reflect(-light_direction, normal);

    float spec = pow(max(dot(view_direction, reflect_direction), 0.0), u_Shininess);
    vec3 specular = light.specular * spec * light.diffuse.xyz * material_specular;

    // Point light attenuation
    float distance = length(light.position.xyz - f_Position);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * distance);
    return (ambient + diffuse + specular) * attenuation * light.intensity;
}

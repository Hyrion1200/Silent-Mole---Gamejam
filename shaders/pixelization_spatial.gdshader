shader_type spatial;

// Normal mode
//#define FACE_NORMALS // Per-face normals
#define BUMP_MAPPING // Per-voxel normals calculated from height map
//#define NORMAL_MAPPING // Per-voxel normals from normal map

// Depth offset - Requires base mesh UV to have unit gradient in view space
//#define DEPTH_OFFSET

uniform sampler2D albedo_map : source_color, filter_nearest;
#ifdef NORMAL_MAPPING
uniform sampler2D normal_map : hint_normal, filter_nearest;
#endif
uniform sampler2D height_map : filter_nearest;
uniform vec2 uv_tiling = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

group_uniforms VoxelTraversal;
/**
 * Automatically scale depth to keep voxels cubic
*/
uniform bool auto_depth = true;
uniform float depth = 0.125;
uniform int levels : hint_range(1, 256) = 8;
uniform int max_steps : hint_range(8, 256) = 64;
group_uniforms;

void vertex() {
	UV = (UV + uv_offset) * uv_tiling;
}

void fragment() {
	// Ray in tangent space
	mat3 tangent_view_matrix = mat3(TANGENT, -BINORMAL, -NORMAL);
	vec3 ray_origin = vec3(UV, 0.0);
	vec3 ray_direction = -VIEW * tangent_view_matrix;
	vec3 ray_sign = sign(ray_direction);
	
	// Scale ray by texture size and depth
	ivec2 i_grid_size = ivec2(textureSize(height_map, 0));
	vec2 f_grid_size = vec2(i_grid_size);
	float f_levels = float(levels);
	float depth_scale = auto_depth ? f_levels / max(f_grid_size.x * uv_tiling.x, f_grid_size.y * uv_tiling.y) : depth;
	
	ray_origin.xy *= f_grid_size;
	ray_direction.xy *= f_grid_size * uv_tiling;
	ray_direction.z /= depth_scale;
	
	// p - texture sample point
	ivec2 p = ivec2(ray_origin.xy);
	ivec2 delta_p = ivec2(ray_sign.xy);
	
	// t - distance along ray
	float t = 0.0;
	vec2 delta_t = abs(1.0 / ray_direction.xy);
	vec2 t_max = (ray_sign.xy * (vec2(p) - ray_origin.xy) + (ray_sign.xy * 0.5) + 0.5) * delta_t;
	
	bool hit = false;
	int axis = 2;
	float voxel_last_z = 0.0;
	for (int i = 0; i < max_steps; i++) {
		float ray_z = ray_direction.z * t;
		
		// Hit top of voxel
		if (voxel_last_z < ray_z) {
			t = voxel_last_z / ray_direction.z;
			p[axis] -= delta_p[axis];
			axis = 2;
			hit = true;
			break;
		}
		
		// Hit side of voxel or bounds
		vec4 voxel = texelFetch(height_map, p % i_grid_size, 0);
		float voxel_z = floor((1.0 - voxel.r) * f_levels) / f_levels;
		if (voxel_z <= ray_z) {
			hit = true;
			break;
		}
		
		axis = t_max.x < t_max.y ? 0 : 1;
		
		t = t_max[axis];
		t_max[axis] += delta_t[axis];
		p[axis] += delta_p[axis];
		voxel_last_z = voxel_z;
	}
	// If no voxel was found, default to mid-plane
	if (!hit) {
		t = (depth_scale * 0.5) / ray_direction.z;
		p = ivec2(ray_origin.xy + ray_direction.xy * t);
		axis = 2;
	}
	
	vec2 offset_uv = vec2(p.xy) / f_grid_size.xy;
	
	// Surface properties
	ALBEDO = texture(albedo_map, offset_uv).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	
#ifdef FACE_NORMALS
	NORMAL = vec3(0.0);
	NORMAL[axis] = -ray_sign[axis];
	NORMAL = tangent_view_matrix * NORMAL;
#endif

#ifdef BUMP_MAPPING
	vec2 pixel = 1.0 / f_grid_size;
	float up = texture(height_map, offset_uv + vec2(0.0, pixel.y)).r;
	float down = texture(height_map, offset_uv - vec2(0.0, pixel.y)).r;
	float right = texture(height_map, offset_uv + vec2(pixel.x, 0.0)).r;
	float left = texture(height_map, offset_uv - vec2(pixel.x, 0.0)).r;
	
	NORMAL_MAP = normalize(vec3(vec2(left - right, down - up) * depth_scale / length(pixel), -1.0));
	NORMAL_MAP = NORMAL_MAP * 0.5 + 0.5;
#endif
	
#ifdef NORMAL_MAPPING
	NORMAL_MAP = texture(normal_map, offset_uv).rgb;
#endif

#ifdef DEPTH_OFFSET
	if (false) discard;
	vec3 view_pos = VERTEX - VIEW * t;
	vec4 clip_pos = PROJECTION_MATRIX * vec4(view_pos, 1.0);
	clip_pos /= clip_pos.w;
	
	LIGHT_VERTEX = view_pos;
	DEPTH = clip_pos.z;
#endif
}
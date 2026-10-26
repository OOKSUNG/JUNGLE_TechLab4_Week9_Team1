import bpy, math
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=r'C:/Code/JUNGLE_TechLab4_Week9_Team1/Assets/Models/Torch/Torch.obj', forward_axis='NEGATIVE_Z', up_axis='Y')
Object = bpy.context.selected_objects[0]
bpy.ops.object.camera_add(location=(2,-3,1.3))
Camera = bpy.context.object
Camera.rotation_euler = (Vector((0,0,0.15)) - Camera.location).to_track_quat('-Z','Y').to_euler()
Camera.data.type = 'ORTHO'
Camera.data.ortho_scale = 1.6
Scene = bpy.context.scene
Scene.camera = Camera
Scene.world = bpy.data.worlds.new('World')
Scene.world.use_nodes = True
Scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.15,0.15,0.15,1)
for Position in [(2,-3,4),(-2,0,2)]:
    bpy.ops.object.light_add(type='AREA',location=Position)
    Light = bpy.context.object
    Light.data.energy = 300
    Light.data.shape = 'DISK'
    Light.data.size = 3
    Light.rotation_euler = (Vector((0,0,0.15)) - Light.location).to_track_quat('-Z','Y').to_euler()
Scene.render.engine = 'CYCLES'
Scene.cycles.samples = 16
Scene.render.resolution_x = 480
Scene.render.resolution_y = 480
Scene.render.resolution_percentage = 100
Scene.render.image_settings.file_format = 'PNG'
Scene.render.filepath = r'C:/Code/JUNGLE_TechLab4_Week9_Team1/Intermediate/TorchLighting/TorchPreview.png'
bpy.ops.render.render(write_still=True)

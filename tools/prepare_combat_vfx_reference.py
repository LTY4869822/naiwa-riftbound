"""Build a narrow, attributed runtime adapter from a pinned MIT source snapshot."""
from pathlib import Path
import hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'references/combat-vfx-demo-mit'
DEST=ROOT/'prototype/third_party/combat_vfx'
SHA='efbcb0e054d6a6ca04df614e95b410afa9aae21b'

def main():
    records=[]
    for path in sorted(SOURCE.rglob('*')):
        if not path.is_file():continue
        relative=path.relative_to(SOURCE)
        if path.name!='LICENSE' and path.suffix not in ['.gd','.gdshader','.gdshaderinc']:continue
        text=path.read_text(encoding='utf-8')
        changes=['res://vfx/ path namespace'] if path.name!='LICENSE' else []
        text=text.replace('res://vfx/','res://third_party/combat_vfx/vfx/')
        if path.name=='trajectory_ribbon.gd':
            start=text.index('\tvar viewport := SubViewport.new()')
            end=text.index('\nfunc reset()',start)
            text=text[:start]+'''\tblade = MeshInstance2D.new()
\tshader_material = ShaderMaterial.new()
\tshader_material.shader = load("res://third_party/combat_vfx/vfx/trajectory_ribbon.gdshader")
\tfor i in 4: shader_material.set_shader_parameter("ink_%d" % i, palette[i])
\tblade.material = shader_material
\tblade.scale = Vector2.ONE * pixel
\tadd_child(blade)
''' + text[end:]
            changes.append('Direct full-resolution mesh instead of a per-effect SubViewport')
        if path.name=='claw_rake.gd':
            start=text.index('\tvar viewport := SubViewport.new()')
            end=text.index('\n\tif follow != null:',start)
            text=text[:start]+'''\t_mesh_node = MeshInstance2D.new()
\t_material = ShaderMaterial.new()
\t_material.shader = load("res://third_party/combat_vfx/vfx/trajectory_ribbon.gdshader")
\tfor i in 4: _material.set_shader_parameter("ink_%d" % i, palette[i])
\t_mesh_node.material = _material
\t_mesh_node.position = _origin
\t_mesh_node.scale = Vector2.ONE * pixel
\tadd_child(_mesh_node)
''' + text[end:]
            text=text.replace('PixelSlash.ease_swing(clampf((time - k * stagger) / duration, 0.0, 1.0))','(1.0 - pow(1.0 - clampf((time - k * stagger) / duration, 0.0, 1.0), 2.4))')
            start=text.index('\tvar transform := Transform2D.IDENTITY',text.index('func head_point()'))
            end=text.index('\n\n## Shape',start)
            text=text[:start]+'\treturn global_transform * point\n'+text[end:]
            changes+=['Direct mesh rendering','Inline the original swing easing','Remove unused ComboStage transform dependency']
        if path.name=='magic_art.gd':
            text=text.replace('static var quality := "explosive"','static var quality := "balanced"')
            changes.append('Balanced density by default; no screen refraction')
        out=DEST/relative
        out.parent.mkdir(parents=True,exist_ok=True)
        out.write_text(text,encoding='utf-8')
        records.append({'path':str(relative).replace('\\','/'),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'runtime_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'changes':changes})
    manifest={'repository':'https://github.com/yuewen-huang/combat-vfx-demo','commit':SHA,'license':'MIT','files':records,'note':'Only modules from this MIT commit are vendored. New enemy event orchestration and custom earth/spore/lantern effects live outside third_party.'}
    (DEST/'SOURCE.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'modules':len(records),'commit':SHA,'license':'MIT'}))

if __name__=='__main__':main()

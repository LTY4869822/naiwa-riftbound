from pathlib import Path
import shutil
import sys

root=Path(__file__).resolve().parents[1]
upstream=root/'references/Naiwa'
dest=root/'desktop'
source=dest/'source'
source.mkdir(parents=True,exist_ok=True)
for name in ['素材.nwp','原版笑声.wav','使用说明.txt','LICENCE','README.md']:
    if '--assets-only' in sys.argv and (dest/name).exists():
        continue
    shutil.copy2(upstream/name,dest/name)
for name in ['AssemblyInfo.cs','Pet.manifest','naiwa.ico']:
    if '--assets-only' in sys.argv and (source/name).exists():
        continue
    shutil.copy2(upstream/'源码'/name,source/name)
if '--assets-only' in sys.argv:
    print('Native assets checked; maintained application sources were preserved.')
    raise SystemExit(0)
text=(upstream/'源码/Naiwa.cs').read_text(encoding='utf-8-sig')
def replace(a,b):
    global text
    assert a in text,a[:100]
    text=text.replace(a,b,1)
replace('private readonly Assets assets;\n        private readonly bool testing;', 'private readonly Assets assets;\n        private GameBridge bridge;\n        private ToolStripMenuItem enterGameItem,returnPetItem;\n        private readonly bool testing;')
replace('menu=BuildMenu();','if(!testing)bridge=new GameBridge(this);\n            menu=BuildMenu();')
replace('if(!fresh){Native.PostMessage(Native.FindWindow(null,Native.Title),Native.Wake,IntPtr.Zero,IntPtr.Zero);return;}', 'if(!fresh){Native.PostMessage(Native.FindWindow(null,Native.Title),args.Length==1&&args[0]=="--game"?0x8003:Native.Wake,IntPtr.Zero,IntPtr.Zero);return;}')
replace('{Application.Run(pet);}', '{if(args.Length==1&&args[0]=="--game")pet.Shown+=delegate{pet.EnterGame();};Application.Run(pet);}')
replace('if(m.Msg==Native.Wake){ReturnHome();return;}', 'if(m.Msg==0x8003){EnterGame();return;}\n            if(m.Msg==Native.Wake){ReturnHome();return;}')
replace('if(args.Length>=2 && args[0]=="--self-test")', 'if(args.Length>=2 && args[0]=="--integration-test") { BridgeTests.Run(args[1]); return; }\n            if(args.Length>=2 && args[0]=="--self-test")')
replace('private ContextMenuStrip BuildMenu()', '''internal void EnterGame(){if(bridge!=null)bridge.Enter();}
        internal GameBridge AttachTestBridge(){bridge=new GameBridge(this,true);return bridge;}
        internal void SetGameActive(bool active)
        {
            if(active){gesture.Cancel();Capture=false;Motion.Suspend(Now);if(sound!=null)sound.Stop();Hide();timer.Interval=100;}
            else{Motion.Suspend(Now);timer.Interval=16;CheckFullscreen(true);if(!HiddenForFullscreen){Show();RenderNow(true);}}
            UpdateMenu();
        }
        private ContextMenuStrip BuildMenu()''')
replace('result.Items.Add("捧腹大笑（双击）",null,delegate{Laugh();});', '''enterGameItem=new ToolStripMenuItem("进入游戏 · 碎片巡游",null,delegate{if(bridge!=null)bridge.Enter();});result.Items.Add(enterGameItem);
            returnPetItem=new ToolStripMenuItem("返回桌宠",null,delegate{if(bridge!=null)bridge.Return();});result.Items.Add(returnPetItem);
            result.Items.Add(new ToolStripSeparator());
            result.Items.Add("捧腹大笑（双击）",null,delegate{Laugh();});''')
replace('if(menu==null)return;SetToggleMark', 'if(menu==null)return;enterGameItem.Text=bridge!=null&&bridge.HasGame?"继续游戏 · 碎片巡游":"进入游戏 · 碎片巡游";returnPetItem.Enabled=bridge!=null&&bridge.Active;SetToggleMark')
replace('if(Now>=nextFullscreenCheck)', 'if(bridge!=null){bridge.Tick();if(bridge.Active)return;}\n            if(Now>=nextFullscreenCheck)')
replace('if(!IsHandleCreated||disposing||HiddenForFullscreen)return;', 'if(!IsHandleCreated||disposing||HiddenForFullscreen||(bridge!=null&&bridge.Active))return;')
replace('if(!ready||menuOpen||gesture.Pressed)return;', 'if(!ready||menuOpen||gesture.Pressed||(bridge!=null&&bridge.Active))return;')
replace('private void ReturnHome(){Home();', 'private void ReturnHome(){if(bridge!=null&&bridge.Active){bridge.Return();}Home();')
replace('Save();timer.Stop();if(sound!=null)', 'Save();timer.Stop();if(bridge!=null)bridge.Dispose();if(sound!=null)')
(source/'Naiwa.cs').write_text(text,encoding='utf-8-sig')
print('Prepared original desktop source and complete original asset pack. Upstream reference unchanged.')

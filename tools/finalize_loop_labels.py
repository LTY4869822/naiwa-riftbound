from pathlib import Path
P=Path(__file__).resolve().parents[1]/'prototype'
for name in ['wardrobe/shop.gd','campaign/jelly_card.gd','v5/ui.gd']:
 p=P/name;s=p.read_text(encoding='utf-8');p.write_text(s.replace('巡游币','金币'),encoding='utf-8')
p=P/'v5/ui.gd';s=p.read_text(encoding='utf-8');s=s.replace('("四境巡游完成" if h.completed_levels.size()==4 else h.current_level().title+" · 已通关")','(h.current_level().map_title+" · 三段通关")');p.write_text(s,encoding='utf-8')

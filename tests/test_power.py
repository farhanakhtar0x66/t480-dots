import runpy,tempfile,unittest
from pathlib import Path
read=runpy.run_path(str(Path(__file__).resolve().parents[1]/'bin/t480-power-state'))['read_power']
class BatteryTest(unittest.TestCase):
 def add(self,root,name,status,pct):
  p=Path(root)/name;p.mkdir();(p/'status').write_text(status);(p/'capacity').write_text(str(pct));(p/'energy_now').write_text(str(pct));(p/'energy_full').write_text('100')
 def test_active_battery_and_switch_when_empty(self):
  with tempfile.TemporaryDirectory() as d:
   self.add(d,'BAT0','Discharging',30);self.add(d,'BAT1','Full',90)
   self.assertEqual(read(Path(d))['percent'],30)
   (Path(d)/'BAT0'/'capacity').write_text('0');(Path(d)/'BAT1'/'status').write_text('Discharging')
   self.assertEqual(read(Path(d))['percent'],90)
 def test_both_empty(self):
  with tempfile.TemporaryDirectory() as d:
   self.add(d,'BAT0','Discharging',0);self.add(d,'BAT1','Full',0)
   self.assertEqual(read(Path(d))['percent'],0)
 def test_no_batteries(self):
  with tempfile.TemporaryDirectory() as d:self.assertIsNone(read(Path(d))['percent'])
if __name__=='__main__':unittest.main()

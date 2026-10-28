import json,os,subprocess,tempfile,unittest
from pathlib import Path
BACKEND=Path(__file__).resolve().parents[1]/'bin/t480-search'
class SearchTest(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.home=Path(self.t.name);self.env=os.environ.copy();self.env.update(HOME=str(self.home),XDG_CACHE_HOME=str(self.home/'.cache'),XDG_DATA_HOME=str(self.home/'.local/share'),PATH=str(Path.home()/'.local/bin')+':'+os.environ['PATH'])
  (self.home/'Projects').mkdir();(self.home/'Projects'/'Quarterly Notes.txt').write_text('x');(self.home/'Projects'/'Unicode résumé.txt').write_text('x')
  (self.home/'.cache').mkdir();(self.home/'.cache'/'not-indexed.txt').write_text('x')
 def tearDown(self):self.t.cleanup()
 def call(self,*args):return json.loads(subprocess.check_output(['python3',str(BACKEND),*args],env=self.env))
 def test_search_files_and_ignore_cache(self):
  self.call('scan');results=self.call('search','launcher','Quarterly')
  self.assertTrue(any(r['kind']=='file' and r['target'].endswith('Quarterly Notes.txt') for r in results))
  self.assertFalse(self.call('search','launcher','not-indexed'))
 def test_search_shortcuts(self):
  self.assertTrue(any('Super+Space' in r['name'] for r in self.call('search','keys','spotlight')))
 def test_query_is_not_a_shell_command(self):
  marker=self.home/'no-injection';self.call('scan');self.call('search','launcher',';touch '+str(marker))
  self.assertFalse(marker.exists())
if __name__=='__main__':unittest.main()

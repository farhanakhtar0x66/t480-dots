"""Compile actual production functions with X drawing replaced by recording stubs."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]

def function(source,name):
    start=source.index('\n'+name+'(')+1
    # Include the return-type line preceding the definition.
    start=source.rfind('\n',0,start-1)+1
    brace=source.index('{',start)
    depth=1;end=brace+1
    while depth:
        if source[end]=='{':depth+=1
        elif source[end]=='}':depth-=1
        end+=1
    return source[start:end]

class LayoutTest(unittest.TestCase):
    def test_real_tile_geometry(self):
        source=(ROOT/'dwm.c').read_text()
        prefix=r'''
#include <assert.h>
#include <stdio.h>
#define MIN(a,b) ((a)<(b)?(a):(b))
#define MAX(a,b) ((a)>(b)?(a):(b))
#define HEIGHT(c) ((c)->h+2*(c)->bw)
#define WIDTH(c) ((c)->w+2*(c)->bw)
#define ISVISIBLE(c) ((c)->visible)
typedef struct Client Client;
typedef struct Monitor Monitor;
struct Client { int x,y,w,h,bw,visible,isfloating; float cfact; Client *next; Monitor *mon; };
struct Monitor { int ww,wh,wx,wy,nmaster; float mfact; Client *clients; };
static int gappx=10,bh=24;
static void resize(Client *c,int x,int y,int w,int h,int unused) {c->x=x;c->y=y;c->w=MAX(bh,w);c->h=MAX(bh,h);}
'''
        config=(ROOT/'config.h').read_text()
        gap=int(re.search(r'gappx\s*=\s*(\d+)',config).group(1))
        factor=float(re.search(r'mfact\s*=\s*([.\d]+)',config).group(1))
        prefix=prefix.replace('gappx=10',f'gappx={gap}')
        parts=[function(source,'nexttiled')]
        if '\ntilecolumn(' in source:parts.append(function(source,'tilecolumn'))
        parts.append(function(source,'tile'))
        test=r'''
int main(void) {
 Monitor m={.ww=1920,.wh=1050,.wx=0,.wy=30,.nmaster=1,.mfact=.5};
 Client c[12]={0};
 for(int i=0;i<12;i++) {c[i].bw=1;c[i].visible=1;c[i].cfact=1;c[i].mon=&m;if(i<11)c[i].next=&c[i+1];}
 for(int count=1;count<=12;count++) {
  c[count-1].next=NULL;m.clients=c;tile(&m);
  assert(c[0].x==10 && c[0].y==40);
  assert(c[0].h+2*c[0].bw==1030);
  if(count>1) {
   assert(WIDTH(&c[0])==945);
   assert(c[1].x-(c[0].x+WIDTH(&c[0]))==10);
   assert(c[1].x+WIDTH(&c[1])==1910);
   assert(c[count-1].y+HEIGHT(&c[count-1])==1070);
   for(int i=1;i<count-1;i++)assert(c[i+1].y-c[i].y-HEIGHT(&c[i])==10);
  } else assert(WIDTH(&c[0])==1900);
  if(count<12)c[count-1].next=&c[count];
 }
 c[1].cfact=2;c[3].next=NULL;tile(&m);
 assert(c[1].h>c[2].h && c[2].h>=c[3].h-1);
 c[1].cfact=.25;c[2].cfact=c[3].cfact=c[4].cfact=4;c[3].next=c+4;c[4].next=NULL;tile(&m);
 assert(c[1].h>=bh);
 for(int i=1;i<4;i++)assert(c[i+1].y-c[i].y-HEIGHT(c+i)==10);
 assert(c[4].y+HEIGHT(c+4)==1070);
 puts("native geometry: 10px gaps, exact 50/50 split and bounded stack heights passed");
}
'''
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'layout.c';path.write_text(prefix+'\n'.join(parts)+test.replace('mfact=.5',f'mfact={factor}'))
            exe=Path(directory)/'layout'
            subprocess.run(['cc','-std=c99','-Wall','-Wextra','-Wno-unused-parameter',str(path),'-o',str(exe)],check=True,capture_output=True,text=True)
            result=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)

if __name__=='__main__':unittest.main()

class NavigationTest(unittest.TestCase):
    def test_real_insertion_navigation_swaps_and_resize(self):
        source=(ROOT/'dwm.c').read_text()
        prefix=r'''
#include <assert.h>
#include <stdio.h>
#define MIN(a,b) ((a)<(b)?(a):(b))
#define MAX(a,b) ((a)>(b)?(a):(b))
#define HEIGHT(c) ((c)->h+2*(c)->bw)
#define WIDTH(c) ((c)->w+2*(c)->bw)
#define ISVISIBLE(c) ((c)->visible)
enum {DirLeft,DirDown,DirUp,DirRight};
typedef union {int i;float f;} Arg;
typedef struct Client Client;
typedef struct Monitor Monitor;
typedef struct {const char *symbol;void (*arrange)(Monitor*);} Layout;
struct Client { int x,y,w,h,bw,visible,isfloating,isfullscreen,isfixed;float cfact;Client *next;Monitor *mon;};
struct Monitor {int ww,wh,wx,wy,nmaster,sellt;float mfact;Client *clients,*sel;const Layout *lt[2];};
static Monitor *selmon;
static int gappx=10,lockfullscreen=1,bh=24;
static void tile(Monitor*);
static void arrange(Monitor *m) {tile(m);}
static void focus(Client *c) {c->mon->sel=c;}
static void restack(Monitor *m) {(void)m;}
static void monocle(Monitor *m) {(void)m;}
static void resize(Client *c,int x,int y,int w,int h,int unused) {(void)unused;c->x=x;c->y=y;c->w=MAX(bh,w);c->h=MAX(bh,h);}
'''
        names=['nexttiled','tilecolumn','tile','setmfact','attachbottom','directionalclient',
               'swapclients','focusdir','shiftdir','resizefocused']
        if '\nfocusstack(' in source:names.insert(names.index('focusdir'),'focusstack')
        parts=[function(source,name) for name in names]
        test=r'''
int main(void) {
 Layout layout={"tile",tile};
 Monitor m={.ww=1920,.wh=1050,.wy=30,.nmaster=1,.mfact=.5};
 m.lt[0]=&layout;selmon=&m;
 Client c[5]={0};
 for(int i=0;i<5;i++) {c[i].mon=&m;c[i].bw=1;c[i].visible=1;c[i].cfact=1;attachbottom(c+i);}
 assert(m.clients==c && c[0].next==c+1 && c[1].next==c+2 && c[4].next==NULL);
 c[3].isfloating=1;c[3].x=1000;c[3].y=42;c[3].w=100;c[3].h=100;
 c[4].visible=0;c[4].x=1000;c[4].y=45;c[4].w=100;c[4].h=100;
 tile(&m);
 assert(directionalclient(c+1,DirDown,1)==c+2);
 assert(directionalclient(c+2,DirUp,1)==c+1);
 assert(directionalclient(c+1,DirLeft,1)==c);
 assert(directionalclient(c,DirRight,1)==c+1);
 assert(directionalclient(c,DirLeft,1)==NULL);
 m.sel=c+1;focusdir(&(Arg){.i=DirDown});assert(m.sel==c+2);
 shiftdir(&(Arg){.i=DirUp});
 assert(m.clients==c && c[0].next==c+2 && c[2].next==c+1 && m.sel==c+2);
 swapclients(c,c+1);
 assert(m.clients==c+1 && c[1].next==c+2 && c[2].next==c && c[0].next==c+3);
 swapclients(c,c+1);
 assert(m.clients==c && c[0].next==c+2 && c[2].next==c+1);
 // All pairs, including both adjacent directions, preserve membership and terminate.
 for(int a=0;a<5;a++)for(int b=0;b<5;b++) {
  swapclients(c+a,c+b);
  int seen[5]={0},n=0;
  for(Client *p=m.clients;p;p=p->next) {assert(++n<=5);int index=p-c;assert(index>=0&&index<5);assert(!seen[index]++);}
  assert(n==5);
  swapclients(c+a,c+b);
 }
 tile(&m);m.sel=c;
 resizefocused(&(Arg){.f=1});assert(m.mfact>.549f && m.mfact<.551f);
 resizefocused(&(Arg){.f=-1});assert(m.mfact>.499f && m.mfact<.501f);
 m.sel=c+2;
 resizefocused(&(Arg){.f=1});assert(c[2].h>c[1].h);
 resizefocused(&(Arg){.f=-1});assert(c[2].h<=c[1].h+1);
 c[1].visible=0;tile(&m);
 resizefocused(&(Arg){.f=1});assert(m.mfact<.451f && WIDTH(c+2)>WIDTH(c));
 m.sel=c+3;int x=c[3].x;
 shiftdir(&(Arg){.i=DirRight});assert(c[3].x==x+40);
 c[3].isfixed=1;int w=c[3].w;resizefocused(&(Arg){.f=1});assert(c[3].w==w);
 Layout mono={"M",monocle};m.lt[0]=&mono;c[3].visible=0;
 c[2].x=c[0].x;c[2].y=c[0].y;c[2].w=c[0].w;c[2].h=c[0].h;
 m.sel=c;focusdir(&(Arg){.i=DirDown});assert(m.sel==c+2);
 focusdir(&(Arg){.i=DirUp});assert(m.sel==c);
 puts("actual C insertion, directional focus, all swap pairs and focused resizing passed");
}
'''
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'navigation.c';path.write_text(prefix+'\n'.join(parts)+test)
            exe=Path(directory)/'navigation'
            result=subprocess.run(['cc','-std=c99','-Wall','-Wextra',str(path),'-o',str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            result=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)

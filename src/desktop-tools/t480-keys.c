#define _POSIX_C_SOURCE 200809L
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void pause_ms(int ms) {struct timespec t={0,ms*1000000};nanosleep(&t,NULL);}
static Window active(Display *d) {
 Window w=None;Atom type;int format;unsigned long count,left;unsigned char *data=NULL;
 XGetWindowProperty(d,DefaultRootWindow(d),XInternAtom(d,"_NET_ACTIVE_WINDOW",False),0,1,False,XA_WINDOW,&type,&format,&count,&left,&data);
 if(data && count==1)w=*(Window*)data;
 if(data)XFree(data);
 return w;
}
int main(int argc,char **argv) {
 if(argc<2)return 2;
 Display *d=XOpenDisplay(NULL);if(!d)return 1;
 Window target=active(d);
 if(!strcmp(argv[1],"active")) {printf("0x%lx\n",target);XCloseDisplay(d);return 0;}
 int paste=!strcmp(argv[1],"paste") || !strcmp(argv[1],"paste-to");
 if(!paste && strcmp(argv[1],"copy")) {XCloseDisplay(d);return 2;}
 if(!strcmp(argv[1],"paste-to")) {
  if(argc!=3)return 2;
  target=strtoul(argv[2],NULL,0);
  /* Allow the picker to unmap; never redirect a paste to a different app. */
  for(int i=0;i<100 && active(d)!=target;i++)pause_ms(5);
 }
 if(!target || active(d)!=target) {XCloseDisplay(d);return 1;}
 XEvent event={0};
 event.xclient.type=ClientMessage;
 event.xclient.display=d;event.xclient.window=target;
 event.xclient.message_type=XInternAtom(d,"_T480_CLIPBOARD_ACTION",False);
 event.xclient.format=32;event.xclient.data.l[0]=paste;
 int ok=XSendEvent(d,DefaultRootWindow(d),False,SubstructureRedirectMask,&event);
 XSync(d,False);XCloseDisplay(d);return ok?0:1;
}

/* Tiny X11 window screenshot utility. PNG goes to stdout, never a permanent file. */
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/Xmu/WinUtil.h>
#include <X11/cursorfont.h>
#include <X11/keysym.h>
#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static Window focused(Display *d, Window root) {
 Atom prop=XInternAtom(d,"_NET_ACTIVE_WINDOW",False),type;
 int fmt; unsigned long n,left; unsigned char *data=NULL; Window w=None;
 if(XGetWindowProperty(d,root,prop,0,1,False,XA_WINDOW,&type,&fmt,&n,&left,&data)==Success && data && n) w=*(Window*)data;
 if(data) XFree(data);
 return w;
}
static Window select_window(Display *d,Window root) {
 Cursor cursor=XCreateFontCursor(d,XC_crosshair);
 if(XGrabPointer(d,root,False,ButtonPressMask|ButtonReleaseMask,GrabModeAsync,GrabModeAsync,None,cursor,CurrentTime)!=GrabSuccess) {XFreeCursor(d,cursor);return None;}
 int keyboard=XGrabKeyboard(d,root,False,GrabModeAsync,GrabModeAsync,CurrentTime)==GrabSuccess;
 Window selected=None; XEvent e; int done=0;
 while(!done) {
  XNextEvent(d,&e);
  if(e.type==KeyPress && XLookupKeysym(&e.xkey,0)==XK_Escape) {selected=None;break;}
  if(e.type==ButtonPress) {if(e.xbutton.button!=Button1) {selected=None;break;} selected=e.xbutton.subwindow;}
  if(e.type==ButtonRelease) done=1;
 }
 XUngrabPointer(d,CurrentTime); if(keyboard) XUngrabKeyboard(d,CurrentTime);
 XFreeCursor(d,cursor); XSync(d,False);
 return selected==None ? None : XmuClientWindow(d,selected);
}
static unsigned char channel(unsigned long pixel,unsigned long mask) {
 if(!mask) return 0;
 while(!(mask&1)) {mask>>=1;pixel>>=1;}
 return (unsigned char)((pixel&mask)*255/mask);
}
int main(int argc,char **argv) {
 if(argc<2 || argc>3) {fputs("Usage: t480-screenshot select|screen|focused|window ID\n",stderr);return 2;}
 Display *d=XOpenDisplay(NULL); if(!d) return 1;
 Window root=DefaultRootWindow(d), w=None;
 if(!strcmp(argv[1],"select")) w=select_window(d,root);
 else if(!strcmp(argv[1],"screen")) w=root;
 else if(!strcmp(argv[1],"focused")) w=focused(d,root);
 else if(!strcmp(argv[1],"window") && argc==3) w=strtoul(argv[2],NULL,0);
 else {XCloseDisplay(d);return 2;}
 if(w==None || (w==root && strcmp(argv[1],"screen"))) {XCloseDisplay(d);return 0;}
 XWindowAttributes a;
 if(!XGetWindowAttributes(d,w,&a) || a.map_state!=IsViewable || a.width<=0 || a.height<=0 || (long)a.width*a.height>32*1024*1024) {XCloseDisplay(d);return 1;}
 XImage *image=XGetImage(d,w,0,0,a.width,a.height,AllPlanes,ZPixmap);
 if(!image) {XCloseDisplay(d);return 1;}
 png_structp png=png_create_write_struct(PNG_LIBPNG_VER_STRING,NULL,NULL,NULL);
 png_infop info=png ? png_create_info_struct(png) : NULL;
 unsigned char *row=malloc((size_t)a.width*3);
 if(!png || !info || !row) return 1;
 if(setjmp(png_jmpbuf(png))) return 1;
 png_init_io(png,stdout);
 png_set_IHDR(png,info,a.width,a.height,8,PNG_COLOR_TYPE_RGB,PNG_INTERLACE_NONE,PNG_COMPRESSION_TYPE_DEFAULT,PNG_FILTER_TYPE_DEFAULT);
 png_write_info(png,info);
 for(int y=0;y<a.height;y++) {
  for(int x=0;x<a.width;x++) {
   unsigned long p=XGetPixel(image,x,y);
   row[x*3]=channel(p,image->red_mask);row[x*3+1]=channel(p,image->green_mask);row[x*3+2]=channel(p,image->blue_mask);
  }
  png_write_row(png,row);
 }
 png_write_end(png,info);png_destroy_write_struct(&png,&info);
 free(row);XDestroyImage(image);XCloseDisplay(d);
 return fflush(stdout)==0 ? 0 : 1;
}

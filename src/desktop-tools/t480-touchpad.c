/* Per-user libinput touchpad preferences; no mouse/TrackPoint changes. */
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/extensions/XInput2.h>
#include <stdio.h>
#include <string.h>

static int boolean_property(Display *d,int device,Atom property) {
 Atom type;int format;unsigned long count,left;unsigned char *data=NULL;int value=-1;
 if(property!=None && XIGetProperty(d,device,property,0,1,False,AnyPropertyType,&type,&format,&count,&left,&data)==Success
    && type==XA_INTEGER && format==8 && count==1 && data)value=data[0];
 if(data)XFree(data);
 return value;
}
int main(int argc,char **argv) {
 int status=argc==2 && !strcmp(argv[1],"--status");
 if(argc>2 || (argc==2 && !status))return 2;
 Display *d=XOpenDisplay(NULL);if(!d)return 1;
 int opcode,event,error;
 if(!XQueryExtension(d,"XInputExtension",&opcode,&event,&error)) {XCloseDisplay(d);return 1;}
 Atom tapping=XInternAtom(d,"libinput Tapping Enabled",True);
 Atom natural=XInternAtom(d,"libinput Natural Scrolling Enabled",True);
 int count=0,result=0;
 XIDeviceInfo *devices=XIQueryDevice(d,XIAllDevices,&count);
 for(int i=0;devices && i<count;i++) {
  XIDeviceInfo *device=&devices[i];
  if(!device->enabled || (device->use!=XISlavePointer && device->use!=XIFloatingSlave))continue;
  /* This libinput capability property is exposed only on touchpads. */
  if(boolean_property(d,device->deviceid,tapping)<0)continue;
  int before=boolean_property(d,device->deviceid,natural);
  if(before<0)continue;
  if(!status) {
   unsigned char enabled=1;
   XIChangeProperty(d,device->deviceid,natural,XA_INTEGER,8,PropModeReplace,&enabled,1);
   XSync(d,False);
  }
  int after=boolean_property(d,device->deviceid,natural);
  printf("%s: natural scrolling=%d\n",device->name,after);
  if(!status && after!=1)result=1;
 }
 if(devices)XIFreeDeviceInfo(devices);
 XCloseDisplay(d);return result;
}

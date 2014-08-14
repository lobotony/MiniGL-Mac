#import <Cocoa/Cocoa.h>
#import <QuartzCore/CVDisplayLink.h>
#import <OpenGL/gl.h>

// implement startup/update/shutdown, watch the threading: startup/shutdown are called on the main ui thread, update is called in the DisplayLink thread
// grab input events through the Window class below
// grab window resize event in app delegate
void startup()
{
  NSLog(@"!! startup on thread: %@ %@", [NSThread currentThread].name, [NSThread currentThread]);
}

// not on main thread
void update()
{
  NSLog(@"!! update on thread: %@ %@", [NSThread currentThread].name, [NSThread currentThread]);
  glClearColor(0, 1, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
}

void shutdown()
{
  NSLog(@"!! shutdown on thread: %@ %@", [NSThread currentThread].name, [NSThread currentThread]);
}

///////////////////////////////////////////////////

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
  NSOpenGLView* glview = (__bridge NSOpenGLView*)displayLinkContext;
  NSOpenGLContext* glcontext = [glview openGLContext];
  [glcontext makeCurrentContext];
  update();
  [glcontext flushBuffer];
  
  return kCVReturnSuccess;
}

@interface LEAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
{
  CVDisplayLinkRef _displayLink;
}
@property (assign) IBOutlet NSWindow *window;
@end

@implementation LEAppDelegate

@synthesize window;

-(void)dealloc
{
  CVDisplayLinkRelease(_displayLink);
}

- (void) quitAction: (id)sender
{
  CVDisplayLinkStop(_displayLink);
  shutdown();
  [[NSApplication sharedApplication] terminate: nil];
}

- (void)windowDidResize:(NSNotification *)notification
{
  //NSRect curFrame = [self.window contentRectForFrameRect:self.window.frame];
  // TODO: send resize event
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  GLint swapInt = 1;
  NSOpenGLView* glview = (NSOpenGLView*)self.window.contentView;
  NSOpenGLContext* glcontext = glview.openGLContext;
  [glcontext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
  CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
  CVDisplayLinkSetOutputCallback(_displayLink, &displayLinkCallback, (__bridge void*)glview);
  CGLContextObj cglContext = (CGLContextObj)[glcontext CGLContextObj];
  CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[[glview pixelFormat] CGLPixelFormatObj];
  CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cglContext, cglPixelFormat);
  CVDisplayLinkStart(_displayLink);
}
@end

@interface LEWindow : NSWindow
@end
@implementation LEWindow
-(void)keyDown:(NSEvent *)theEvent {}
-(void)keyUp:(NSEvent *)theEvent {}
-(void)mouseDown:(NSEvent *)theEvent {}
-(void)mouseUp:(NSEvent *)theEvent {}
-(void)mouseDragged:(NSEvent *)theEvent {}
-(void)mouseMoved:(NSEvent *)theEvent {}
@end

int main(int argc, char *argv[])
{
  NSApplication* app = [NSApplication sharedApplication];
  LEAppDelegate* appDelegate = [[LEAppDelegate alloc] init];  // required for some important callbacks

  // setup very basic menu so we can at least CMD-Q quit
  NSMenu *menu;
  NSMenuItem *menu_item, *temp_item;
  NSString* title = nil;
  NSDictionary* app_dictionary = [[NSBundle mainBundle] infoDictionary];
  if (app_dictionary) 
  {
    title = [app_dictionary objectForKey: @"CFBundleName"];
  }
  if (title == nil) 
  {
    title = [[NSProcessInfo processInfo] processName];
  }
  NSMenu *main_menu = [[NSMenu allocWithZone: [NSMenu menuZone]] initWithTitle: @"temp"];
  [app setMainMenu: main_menu];
  menu = [[NSMenu allocWithZone: [NSMenu menuZone]] initWithTitle: @"temp"];
  temp_item = [[NSMenuItem allocWithZone: [NSMenu menuZone]]
               initWithTitle: @"temp"
               action: NULL
               keyEquivalent: @""];
  [[app mainMenu] addItem: temp_item];
  [[app mainMenu] setSubmenu: menu forItem: temp_item];
  NSString *quit = [@"Quit " stringByAppendingString: title];
  menu_item = [[NSMenuItem allocWithZone: [NSMenu menuZone]]
               initWithTitle: quit
               action: @selector(quitAction:)
               keyEquivalent: @"q"];
  [menu_item setKeyEquivalentModifierMask: NSCommandKeyMask];
  [menu_item setTarget: appDelegate];
  [menu addItem: menu_item];
  
  [app setDelegate: appDelegate];

  CGFloat width = 640;
  CGFloat height = 480;
  CGRect fr = CGRectMake(0, 0, width, height);
  const NSOpenGLPixelFormatAttribute windowedAttributes[] =
  {
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFAAccelerated,
    NSOpenGLPFAColorSize, [[[NSUserDefaults standardUserDefaults] objectForKey:@"colorDepth"] unsignedIntValue],
    NSOpenGLPFAAlphaSize, 8,
    NSOpenGLPFADepthSize, 32,
    0
  };  
  NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: windowedAttributes];
  
  NSOpenGLView* glview = [[NSOpenGLView alloc] initWithFrame:fr pixelFormat:pixelFormat];

  // make context current for this thread to be able to safely call startup
  [[glview openGLContext] makeCurrentContext];
  startup();
  [NSOpenGLContext clearCurrentContext]; // then clear the context for this thread, so it's later only active on the render thread
  
  LEWindow* window = [[LEWindow alloc]
                      initWithContentRect: fr
                      styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                      backing: NSBackingStoreBuffered
                      defer: NO];
  [window setTitle: @"Minimal GL App"];
  [window setAcceptsMouseMovedEvents: YES];
  [window setContentView: glview];
  [window setDelegate: appDelegate];
  [window setReleasedWhenClosed: NO];
  [window makeKeyAndOrderFront:nil]; // shows and focuses the window
  appDelegate.window = window;
  [app run]; // runs the actual app, doesn't return
  
  return EXIT_SUCCESS;
}


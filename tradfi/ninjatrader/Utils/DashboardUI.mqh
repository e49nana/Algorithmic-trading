//+------------------------------------------------------------------+
//|                                              DashboardUI.mqh     |
//|  Generic MT5 Dashboard / GUI Utilities                           |
//|                                                                  |
//|  Provides reusable helpers for building dashboards:              |
//|    • Panels (rectangle labels)                                   |
//|    • Text labels                                                 |
//|    • Buttons                                                     |
//|    • Bitmap logos                                                |
//|    • Progress bars                                               |
//|    • Prefix-based cleanup                                        |
//|                                                                  |
//|  Usage example:                                                  |
//|    #include <utils/DashboardUI.mqh>                              |
//|    DashCreateRectPanel("EA_", "MAIN", CORNER_LEFT_UPPER, ...);   |
//+------------------------------------------------------------------+
#property strict

// Build full object name from prefix + ID
string DashName(const string prefix,const string id)
{
   return(prefix + id);
}

//------------------------------------------------------------------
// Create rectangular panel (OBJ_RECTANGLE_LABEL)
//------------------------------------------------------------------
void DashCreateRectPanel(const string prefix,
                         const string name,
                         int corner,
                         int x,int y,
                         int w,int h,
                         color bg,
                         color border,
                         bool front=true,
                         int zorder=0)
{
   string full = DashName(prefix,name);
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_CORNER,       corner);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, full, OBJPROP_COLOR,        border);
   ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, full, OBJPROP_BACK,         !front);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN,       false);
   ObjectSetInteger(0, full, OBJPROP_ZORDER,       zorder);
}

//------------------------------------------------------------------
// Create text label (OBJ_LABEL)
//------------------------------------------------------------------
void DashCreateLabel(const string prefix,
                     const string name,
                     int corner,
                     int x,int y,
                     const string text,
                     int fontsize,
                     color clr,
                     bool center=false,
                     int zorder=0,
                     const string font="Arial Rounded MT Bold")
{
   string full = DashName(prefix,name);
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_CORNER,     corner);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE,   fontsize);
   ObjectSetInteger(0, full, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, full, OBJPROP_BACK,       false);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN,     false);
   ObjectSetInteger(0, full, OBJPROP_ZORDER,     zorder);
   ObjectSetString (0, full, OBJPROP_FONT,       font);
   ObjectSetString (0, full, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, full, OBJPROP_ANCHOR,
                    center ? ANCHOR_CENTER : ANCHOR_LEFT_UPPER);
}

//------------------------------------------------------------------
// Create button (OBJ_BUTTON)
//------------------------------------------------------------------
void DashCreateButton(const string prefix,
                      const string name,
                      int corner,
                      int x,int y,
                      int w,int h,
                      const string text,
                      color clrBG,
                      int zorder=0)
{
   string full = DashName(prefix,name);
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_CORNER,      corner);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR,     clrBG);
   ObjectSetInteger(0, full, OBJPROP_COLOR,       clrBG);
   ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE,  true);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN,      false);
   ObjectSetInteger(0, full, OBJPROP_ZORDER,      zorder);
   ObjectSetString (0, full, OBJPROP_FONT,        "Arial Rounded MT Bold");
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE,    9);
   ObjectSetString (0, full, OBJPROP_TEXT,        text);
}

//------------------------------------------------------------------
// Create bitmap logo (OBJ_BITMAP_LABEL)
//------------------------------------------------------------------
void DashCreateBitmapLogo(const string prefix,
                          const string name,
                          int corner,
                          int x,int y,
                          const string file,
                          int zorder=0)
{
   if(file=="") return;

   string full = DashName(prefix,name);
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_BITMAP_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_CORNER,     corner);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, full, OBJPROP_BACK,       false);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN,     false);
   ObjectSetInteger(0, full, OBJPROP_ZORDER,     zorder);
   ObjectSetString (0, full, OBJPROP_BMPFILE,    file);
}

//------------------------------------------------------------------
// Update progress bar width (rectangle label with dynamic width)
//------------------------------------------------------------------
void DashUpdateRectWidth(const string prefix,
                         const string name,
                         int corner,
                         int x,int y,
                         int h,
                         int newWidth,
                         color bg,
                         color border,
                         int zorder)
{
   string full = DashName(prefix,name);
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_CORNER,       corner);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE,        newWidth);
   ObjectSetInteger(0, full, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, full, OBJPROP_COLOR,        border);
   ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN,       false);
   ObjectSetInteger(0, full, OBJPROP_ZORDER,       zorder);
}

//------------------------------------------------------------------
// Delete all dashboard objects sharing a prefix
//------------------------------------------------------------------
void DashDeleteAll(const string prefix)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total-1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+

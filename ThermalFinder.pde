float falloff_ratio = 0.02;
//float falloff_ratio = 0.005;
float falloff_cutoff = 0.05;
float sink = 0.2; // the "sink rate" of the glider in zero lift, only used to draw the minimum vario value

// the relationship between how fast lift changes
// and how fast our turning radius changes
float turn_ratio = 1;

float max_turn_speed = PI/20;

Glider glider;
ArrayList<Thermal> thermals;

float[] lift;

void calculateLift(ArrayList<Thermal> thermals) {
  for (int x=0; x<width; x++) {
    for (int y=0; y<height; y++) {
      float cur = 0;
      for (int i=0; i<thermals.size(); i++) {
        Thermal t = thermals.get(i);
        float distance = sqrt(sq(t.x - x) + sq(t.y - y));
        // assume strength falls off per inverse square law
        float strength = t.strength / (sq(distance*falloff_ratio));
        
        // assume strength falls off linearly
        //float strength = t.strength - t.strength * distance * falloff_ratio;
        
        strength = clamp(strength, 0, 1);
        cur += strength;

      }
      lift[y*width + x] = cur;
    }
  }
}

// if the input is below or above the minimum or maximum values,
// returns the minimum or maximum-1 (for array bounding)
// else returns the input
int clamp(int in, int min, int max) {
  int out = in;
  if (out < min) {
    out = min;
  }
  if (out >= max) {
    out = max-1;
  }
  return out;
}

// if the input is below or above the minimum or maximum values,
// returns the minimum or maximum
// else returns the input
float clamp(float in, float min, float max) {
  float out = in;
  if (out < min) {
    out = min;
  }
  if (out >= max) {
    out = max;
  }
  return out;
}

void drawLift(int x1, int y1, int x2, int y2) {
  loadPixels();
  x1 = clamp(x1, 0, width);
  x2 = clamp(x2, 0, width);
  y1 = clamp(y1, 0, height);
  y2 = clamp(y2, 0, height);
  
  for (int x=x1; x<x2; x++) {
    for (int y=y1; y<y2; y++) {
      float cur = lift[y*width + x];
      if (cur > 1) {
        cur = 1; // cap at 1 strength
      }
      // map value (0-1) to hue (180-0)
      int hue = (int)(180 - cur * 180);
      color cur_color = color(hue, 90, 90);
      pixels[y*width + x] = cur_color;
    }
  }
  updatePixels();
}

final int VARIO_PIXELS_PER_LIFT = 4*height; // convert lift to how big the vario bar will be
final int VARIO_WIDTH = 30;
void drawVario(float lift) {

  float y = height/2;
  float x = width - VARIO_WIDTH - 10;
  color cur_color = color(120, 90, 90); // green
  if (lift-sink < 0) {
    cur_color = color(0, 90, 90); // red
  }
  fill(cur_color);
  
  rect(x, y, VARIO_WIDTH, -VARIO_PIXELS_PER_LIFT*(lift-sink));  
}

void undrawVario(float lift) {
  //float y = height/2;
  //float x = width - 20;
  float x1 = width - VARIO_WIDTH - 10;
  float x2 = width - 9;
  drawLift((int)x1, 0, (int)x2, height);  
  
  //drawLift((int)x, (int)y, (int)x+10, -(int)(y+VARIO_PIXELS_PER_LIFT*(lift-sink)));
}

class Glider {
  float velocity = 10;
  int size = 20;
  float angle = 0;
  int x = 0;
  int y = 0;
  
  float prev_lift;
  
  float turn_velocity = 0;

  
  Glider(int x, int y, float angle) {
    this.x = x;
    this.y = y;
    this.angle = angle;
  }
  
  void move() {
    // calculate turn velocity based on current conditions
    float cur_lift = lift[y*width + x];
    drawVario(cur_lift);
    //println("lift = ", cur_lift);
    float delta_lift = cur_lift - prev_lift;
    //println("Delta lift: " , delta_lift);
    prev_lift = cur_lift;
    
    if (delta_lift > 0) {
      //println("Turning slower");
      // give a slight boost to slowing down
      // this helps prevent turning in circles outside of the thermals
      delta_lift *= 1.5;
    } else if (delta_lift < 0) {
      //println("Turning faster");
    } else {
      //println("No Change");
    }
    
    // if lift is decreasing, increase turn velocity, and vice versa
    float new_turn = turn_velocity - (delta_lift * turn_ratio);
    
    // turn velocity can never go below 0
    // keep turn velocity from reaching ludicrous values by enforcing a maximum turn speed
    turn_velocity = clamp(new_turn, 0, max_turn_speed);
    //println("Turn Velocity: ", turn_velocity);
    
    // sin and cos are confusing here as the glider triangle points towards +y
    // mod by width and height for screen wrapping
    x = (int)(x+velocity*-sin(angle)+width)%width;
    y = (int)(y+velocity*cos(angle)+height)%height;
    angle = angle+turn_velocity;
  }
  
  // Triangles are easy, let's use that
  void draw() {
    stroke(0);
    fill(255);
    // Cheeky translation and rotation so we don't have to do math
    translate(x, y);
    rotate(angle);
    triangle(0, size, -size/2, -size/2, size/2, -size/2);
    rotate(-angle);
    translate(0,0);
  }
  
  // Since redrawing the entire screen is taxing, we can redraw just the space the trangle covered
  void undraw() {
    drawLift(x-size, y-size, x+size, y+size);
    undrawVario(lift[y*width + x]);
  }
}

class Thermal {
  float x, y;
  float strength; // between 0 and 1
  float vel_x, vel_y;
  
  Thermal(int x, int y, float strength) {
    this.x = x;
    this.y = y;
    this.strength = strength;
  }
  
  void move() {
    vel_x = vel_x + random(1) - 0.5;
    vel_y = vel_y + random(1) - 0.5;
    
    x = x + vel_x;
    y = y + vel_y;
  }
}

void draw() {
  //background(180, 90, 90);
  //for (int i=0; i<thermals.size(); i++) {
    //thermals.get(i).move();
  //}
  glider.undraw();
  glider.move();
  glider.draw();

}

void setup() {
  size(2000, 2000);
  lift = new float[width * height];
  colorMode(HSB, 360, 100, 100);
  ellipseMode(RADIUS);
  frameRate(60);
  glider = new Glider((int)random(width), int(random(height)), int(random(2*PI)));
  Thermal thermal1 = new Thermal((int)random(width/2)+width/4, int(random(height)/2+height/4), 3);
  Thermal thermal2 = new Thermal((int)random(width/2)+width/4, int(random(height)/2+height/4), 3);
  thermals = new ArrayList<Thermal>();
  thermals.add(thermal1);
  thermals.add(thermal2);
  calculateLift(thermals);
  drawLift(0, 0, width, height);
}

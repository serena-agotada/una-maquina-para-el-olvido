#define outputA 6
#define outputB 7
#define boton 8

int cant_videos = 65;

int redpin = 11; // pin for red signal
int greenpin = 10; // pin for green signal
int bluepin = 12;

int val_r;
int val_g;
int dir_r, dir_g;

int counter = 0;
int aState;
int aLastState;
int nitidez = 0;
int nitidez_ant = 0;

int inactividad = 0;

int max_valores_dial;

void setup() {
  pinMode (outputA,INPUT);
  pinMode (outputB,INPUT);
  pinMode (boton, INPUT_PULLUP);

  pinMode(redpin, OUTPUT);
	pinMode(greenpin, OUTPUT);
  pinMode(bluepin, OUTPUT);

  Serial.begin (9600);
  aLastState = digitalRead(outputA);   //Leemos el valor incial

  val_r = 0;
  val_g = 255;

  max_valores_dial = 4+((cant_videos+1) * 10);
}

void loop() {
  aState = digitalRead(outputA);
  nitidez = analogRead(A0);

  if (aState != aLastState )
    {
        if (digitalRead(outputB) != aState) 
            counter ++;
        else
            counter --;

        if ( counter >= max_valores_dial )
        { 
          counter = 0 ;
        }
        else if ( counter <= -1 )
        { 
          counter = max_valores_dial ;
        }

        Serial.print(counter);
        Serial.print(" ");
        Serial.print(nitidez);
        Serial.print(" ");
        Serial.println(inactividad);

        aLastState = aState; // Guardamos el ultimo valor
        inactividad = 0;
    }
    else if(nitidez != nitidez_ant && millis() % 100 == 0){
      Serial.print(counter);
      Serial.print(" ");
      Serial.print(nitidez);
      Serial.print(" ");
      Serial.println(inactividad);

      if(abs(nitidez - nitidez_ant) > 16) inactividad = 0;

      nitidez_ant = nitidez;
      
    }
    else if(millis() % 100 == 0){
      inactividad++;
    }

    if(millis() % 35 == 0){
      //LED
      if(val_r >= 255) dir_r = -1;
      else if(val_r <= 0) dir_r = 1;

      if(val_g >= 255) dir_g = -1;
      else if(val_g <= 0) dir_g = 1;


      if(inactividad > 150){
        if(val_g > 0) val_g--;
        else val_r += dir_r;
      }
      else if(inactividad < 5){
        if(val_r > 0) val_r--;
        else if(val_g < 255) val_g++;
      }
      else{
        if(val_r > 0) val_r--;
        else val_g += dir_g;
      }

      analogWrite(redpin, val_r); 
      analogWrite(bluepin, val_g); 
      analogWrite(greenpin, val_g); 
    }
  

  bool B = digitalRead(boton);
  if ( !B )
  { 
    counter = 0 ;
  }


  //delay(200);
}

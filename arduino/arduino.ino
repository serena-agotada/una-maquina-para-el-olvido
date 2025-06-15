#define outputA 6
#define outputB 7
#define boton 8

int redpin = 11; // pin for red signal
int greenpin = 10; // pin for green signal
int val_r;
int val_g;
int dir_r, dir_g;

int counter = 0;
int aState;
int aLastState;
int nitidez = 0;
int nitidez_ant = 0;

int inactividad = 0;

void setup() {
  pinMode (outputA,INPUT);
  pinMode (outputB,INPUT);
  pinMode (boton, INPUT_PULLUP);

  pinMode(redpin, OUTPUT);
	pinMode(greenpin, OUTPUT);

  Serial.begin (9600);
  aLastState = digitalRead(outputA);   //Leemos el valor incial

  val_r = 0;
  val_g = 255;

}

void loop() {
  aState = digitalRead(outputA);
  nitidez = map(analogRead(A0), 0, 673, 0, 1023);

  if (aState != aLastState )
    {
        if (digitalRead(outputB) != aState) 
            counter ++;
        else
            counter --;

        if ( counter == 59*30 )
        { 
          counter = 0 ;
        }
        else if ( counter == -1 )
        { 
          counter = 59*30-1 ;
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

      if(abs(nitidez - nitidez_ant) > 3) inactividad = 0;

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
      analogWrite(greenpin, val_g); 
    }
  

  bool B = digitalRead(boton);
  if ( !B )
  { 
    counter = 0 ;
  }


  //delay(200);
}

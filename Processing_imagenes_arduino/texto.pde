// TEXTO --------------------------------------------------------------------------------------------------------------------------

void calcularTexto() {
  texto = textos[clip][indice_imagen];

  if (transicionImagenes < 0.5) {
    texto_random = texto.substring(0, caracteres_escritos);
  } else if (transicionImagenes > 0.8) {
    texto_random = "Pensando...";
  } else if (frameCount % 6 == 0) {
    texto_random = "";
    for (int i=0; i < caracteres_escritos; i++) {
      if (random(1) < transicionImagenes && i < texto.length() && texto.charAt(i) != ' ' && texto.charAt(i) != '.' && texto.charAt(i) != ',') {
        int randChar = int( random(0, texto.length()-1) );

        while (texto.charAt(randChar) == ' ' || texto.charAt(randChar) == '.' || texto.charAt(randChar) == ',') {
          randChar = int(random(0, texto.length()-1));
        }

        texto_random += texto.charAt(randChar);
      } else if (i < texto.length()) texto_random += textos[clip][indice_imagen].charAt(i);
    }
  }

  int velocidad_escritura = int(map(transicionImagenes+distortionAmount, 0, 2, 20, 3)); // cantidad de caracteres escritos por frame

  if (caracteres_escritos < texto.length() - velocidad_escritura - 1) {
    texto_random += "|";
    caracteres_escritos+= velocidad_escritura;
  } else if (caracteres_escritos < texto.length()) {
    caracteres_escritos++;
  } else if (caracteres_escritos > texto.length()) {
    caracteres_escritos = texto.length();
  }

  try {
    byte[] utf8 = texto_random.getBytes("UTF-8");
    OscMessage m = new OscMessage("/texto");
    m.add(utf8);
    oscP5.send(m, loc_texto);
  }
  catch(Exception e) {
    e.printStackTrace();
  }
}

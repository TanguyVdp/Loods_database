-- Zet de wachtrij-snelheid terug naar 5 zakjes/2 min (de reset zette 'm
-- terug naar de standaardwaarde 3/3). Ratio blijft ongewijzigd op 2:1.
update loods_baseline set batch_size = 5, batch_minutes = 2 where id = true;

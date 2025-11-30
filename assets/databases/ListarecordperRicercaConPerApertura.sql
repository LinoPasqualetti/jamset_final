 select distinct percradice||percresto||Volume as PerApertura,Numpag,titolo,volume,ArchivioProvenienza, strumento,primolink, percradice,percresto 
 from Spartiti where tipoMulti like 'PD%' and titolo like 'love%'
 order by titolo,strumento
 



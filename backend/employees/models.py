from django.db import models
 
class Employee(models.Model):
    name       = models.CharField(max_length=100)
    dob        = models.DateField()
    doj        = models.DateField()
    ctc        = models.FloatField()
    photo      = models.ImageField(upload_to='photos/', null=True, blank=True)
    latitude   = models.FloatField(null=True, blank=True)
    longitude  = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
 
    def __str__(self):
        return self.name

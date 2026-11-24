from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("hotels", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="hotel",
            name="hotel_type",
            field=models.CharField(
                choices=[
                    ("CUSTOMER_HOTEL", "Customer Hotel"),
                    ("FOOD_PARTNER", "Food Partner"),
                ],
                default="CUSTOMER_HOTEL",
                max_length=20,
            ),
        ),
    ]

package com.example.kotlincoolerapp

import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(50, 50, 50, 50)
        }

        val textView = TextView(this).apply {
            text = "سلام! این اولین اپ کاتلین من است."
            textSize = 20f
        }

        val button = Button(this).apply {
            text = "کلیک کن!"
            setOnClickListener {
                textView.text = "دکمه کلیک شد! (کد کاتلین کار می‌کند)"
            }
        }

        layout.addView(textView)
        layout.addView(button)
        setContentView(layout)
    }
}

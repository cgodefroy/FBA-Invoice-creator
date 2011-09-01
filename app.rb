#!/usr/bin/env ruby

require 'rubygems'
require 'prawn'
require 'prawn/layout'
require 'csv'
require 'date'

class App

  MY_LOGO = "logoecomposite.png"
  VAT = 0.196

  def run
    $invoice_ref = get_invoice_number
    $invoice_ref = $invoice_ref.to_i
    invoice = Invoice.new(get_csv)
  end

  def get_client_name
    print "Client: "
    gets.chomp
  end

  def get_invoice_number
    print "Invoice number: "
    gets.chomp
  end

  def get_csv
    printf "Amazon Export: "
    gets.chomp
  end

  class Invoice
    attr_reader :items
    
    def oldinitialize(file)
      @items = []
      @total_hours = 0.0
      @grand_total = 0.0
      CSV.foreach(file, :headers=>true, :converters=>:numeric) do |data|
        #cost_sub = sub_total(data)
        cost_sub = '0'
        @items << [ data[0], data[1], float_format(data[4]), cost_sub ]
        @grand_total += cost_sub.to_f
      end
    end
    
    def initialize(file)
      @order_id = ''
      @former_invoice_id = ''
      $shipping_cost = 0.0
      $grand_total = 0
      CSV.open(file,'r',"\t").each do |data|
      #CSV.foreach(file, :converters=>:numeric, :row_sep =>:auto, :col_sep =>'^t') do |data|
        @order_id = data[0]
        if (@order_id != @former_invoice_id) #New order, flush previous
          if($items)
            printFinalInvoice
          end
          
          $buyer = data[11]
          $billline1 = data[33]
          $billline2 = data [34]
          $billcity = data[36]
          $billpostalcode = data[38]
          $order_date = Date.strptime(data[6]) if (data[6])
          $shipping_cost = data[19].to_f
          $devise = data[16]
          $grand_total = 0
          $items = []
          $items << [ "", "Quantité", "Prix", "Total" ]
          
          @former_invoice_id = @order_id
        else  #Meme commande
          $shipping_cost += data[19].to_f
          
        end
        item_total = line_total(data)
        @quantity = data[15]
        @item_price = data[17]
        
        $grand_total += (@quantity.to_f * @item_price.to_f)
        $items << [ data[14], @quantity, @item_price, item_total ]
        
      end
      #Print last line of csv 
      printFinalInvoice
    end
    
    def printFinalInvoice
      $grand_total += $shipping_cost
      @vat = $grand_total*(VAT/(1+VAT))
      @gross_total = $grand_total-@vat
      
      $items << [ "Transport", "", "", line_format($shipping_cost, $devise)]
      $items << ["Total HT", "", "", line_format(@gross_total, $devise)]
      $items << ["TVA", "19,6%", "", line_format(@vat, $devise)]
      $items << ["Total TTC","","",line_format($grand_total, $devise)]
      createPdf
      $invoice_ref += 1
    end

    def float_format(value)
      unless value.nil?
        '%.2f' % value
      end
    end

    def line_total(data)
      '%.2f %s' % [(data[15].to_f * data[17].to_f) , data[16]]
    end
    
    def line_format(value, devise)
      '%.2f %s' % [value, devise]
    end

    def sub_total(data)
      if data[4] == nil
        float_format data[5]
      else
        float_format(data[4] * MY_RATE)
      end
    end

    
    def createPdf
      Prawn::Document.generate("#{$invoice_ref}.pdf") do
        image MY_LOGO, :scale => 1, :position => :left,  :vposition => :top

        move_down 10
        font_size 22
        text "Facture: Shop-#{$invoice_ref.to_s}", :position => :left, :vposition => :top
        font_size 12
        text "#{$order_date.strftime("%d/%m/%Y")}" if ($order_date)
        
        font_size 12
        bounding_box [350, cursor], :width => 180 do
          text "#{$buyer}"
          text "#{$billline1}"
          text "#{$billline2}"
          text "#{$billpostalcode} #{$billcity}"
        end
        move_down 30

        table $items, :width => bounds.width, :row_colors => ["FFFFFF","efefff"]

        move_down 30
        #text "Total amount payable: #{timesheet.grand_total}"

        move_cursor_to 50
        font_size 10
        text "eCOMPOSITE - SARL au capital de 7 500 euros - Siren 452 183 411 RCS de Paris", :align => :center
        move_down 4
        text "128 rue La Boëtie - 75008 Paris", :align => :center
        move_down 4
        text "TVA FR07 452 183 411", :align => :center
      end
    end
  end

end

app = App.new
app.run

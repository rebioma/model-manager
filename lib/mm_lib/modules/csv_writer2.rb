module CsvWriter2
  def CsvWriter2.write_csv(occ_array,outfile,col_names,skiplist)
    csv_file = File.new(outfile,"w")
    header = col_names.clone
    header << "reviewers" # Add new field for reviewers
    # remove fields from skiplist from header
    skiplist.each{|skip|
      header.delete(skip)
    }
    csv_file.puts(header.join(","))
    rec_id = ""
    occ_array.each{|occ|
      line = []
      col_names.each {|field|
        rec_id = occ.id
        value = occ[field]
        value = "" if (field == "email" and occ.email_visible == false)
        #puts "field:" + field
        #puts "value: " + value.to_s
        #puts "----------------------------"
        line << value.to_s unless skiplist.include?(field)
      }
      # Get list of reviews (if any) to add to csv
      review_array = Occurrence.find_by_id(rec_id).reviews
      emails = []
      review_array.each {|review| emails << review.user.email }
      line << emails.join(" | ")
      #puts "line:"
      #puts line.join(",")
      csv_file.puts(line.join(","))
    }
    csv_file.flush
    csv_file.close
    return csv_file
  end
end

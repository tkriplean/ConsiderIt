require 'uri'

namespace :metrics do
  desc "Create metrics output"

  task :deeper => :environment do
    puts "Number\tName\tpositions\tpoints\tinclusions\tInclusions per point\tInclusions per position"
    Proposal.where(:domain_short => 'WA State').each do |p|
      printf("%i\t%s\t%i\t%i\t%i\t%.2f\t%.2f\n",
        p.designator,p.short_name,p.positions.published.count,p.points.published.count,p.inclusions.count,
        p.inclusions.count.to_f / p.points.published.count,
        p.inclusions.count.to_f / p.positions.published.count)
    end
  end

  task :basic => :environment do

    WASHINGTON = false
    if WASHINGTON
      years = [2010,2011,2012]
      accnt_id = 1
    else
      years = [2012]
      accnt_id = 2
    end

    puts "Overall activities"
    puts "Year\tusers\tpositions\tinclusions\tpoints\tcomments"
    years.each do |year|
      positions = Position.published.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8')
      users = User.where(:account_id => accnt_id).where("YEAR(created_at)=#{year} OR YEAR(last_sign_in_at)=#{year}").where('MONTH(created_at)>8')
      points = Point.published.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8')      
      inclusions = Inclusion.where(:account_id => accnt_id).where("YEAR(inclusions.created_at)=#{year}").where('MONTH(inclusions.created_at)>8').joins(:position).where('positions.published = 1')
      comments = Commentable::Comment.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8')

      printf("%i\t%s\t%i\t%i\t%i\t%i\n",
          year, users.count, positions.count, inclusions.count, points.count, comments.count)

    end

    puts "Distinct users engaging in each activity"
    puts "Year\tusers\tpositions\tinclusions\tpoints\tcomments"
    years.each do |year|
      positions = Position.published.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8').group(:user_id)
      users = User.where(:account_id => accnt_id).where("YEAR(created_at)=#{year} OR YEAR(last_sign_in_at)=#{year}").where('MONTH(created_at)>8')
      points = Point.published.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8').group(:user_id)
      inclusions = Inclusion.where(:account_id => accnt_id).where("YEAR(inclusions.created_at)=#{year}").where('MONTH(inclusions.created_at)>8').joins(:position).where('positions.published = 1').group("inclusions.user_id")
      comments = Commentable::Comment.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8').group(:user_id)

      printf("%i\t%s\t%i\t%i\t%i\t%i\n",
          year, 
          users.count, 
          positions.count.keys.length, 
          inclusions.count.keys.length, 
          points.count.keys.length, 
          comments.count.keys.length)

    end

    puts "Advanced metrics"
    puts "Year\tInclusions per point\tinclusions per position\tcomments per point\tpositions per user"
    years.each do |year|
      positions = Position.published.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8')
      users = User.where(:account_id => accnt_id).where("YEAR(created_at)=#{year} OR YEAR(last_sign_in_at)=#{year}").where('MONTH(created_at)>8')
      points = Point.published.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8')      
      inclusions = Inclusion.where(:account_id => accnt_id).where("YEAR(inclusions.created_at)=#{year}").where('MONTH(inclusions.created_at)>8').joins(:position).where('positions.published = 1')
      comments = Commentable::Comment.where(:account_id => accnt_id).where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8')

      printf("%i\t%.2f\t%.2f\t%.2f\t%.2f\n",
          year, 
          inclusions.count.to_f / points.count, #inclusions per point
          inclusions.count.to_f / positions.count, #inclusions per position
          comments.count.to_f / points.count, #comments per point
          positions.count.to_f / users.count #positions per user
      )
    end
  end

  task :fill_position_holes => :environment do 
    Point.published.where(:position_id => nil).each do |pnt|
      pnt.position = Position.where(:user_id => pnt.user_id).where(:proposal_id => pnt.proposal_id).last
      pnt.save
    end
    Inclusion.where(:position_id => nil).each do |inc|
      inc.position = Position.published.where(:user_id => inc.user_id).where(:proposal_id => inc.proposal_id).last
      inc.save
    end
  end

  task :normative_inclusion_overall => :environment do
    WASHINGTON = true
    if WASHINGTON
      years = [2010,2011,2012]
      accnt_id = 1
    else
      years = [2012]
      accnt_id = 2
    end

    puts "Normative metrics"
    puts "Year\tIncluded pro & con\tIncluded point by opposition\tIncluded for your side\tIncluded for other side\tConviction"
    years.each do |year|
      positions = Position.published.where(:account_id => accnt_id).where("YEAR(positions.created_at)=#{year}").where('MONTH(positions.created_at)>8').joins(:user).where('users.roles_mask=0')

      pro_and_con = 0
      not_pro_and_con = 0
      neither = 0
      inc_yr_side = 0
      inc_other_side = 0

      THRESH = 1
      conviction = 0

      positions.each do |pos|
        if pos.inclusions.count >= THRESH
          inc_points = pos.inclusions.joins(:point)
          conviction += pos.stance.abs
          if inc_points.where('points.is_pro=1').count > 0 && inc_points.where('points.is_pro=0').count > 0
            pro_and_con += 1
          else  
            not_pro_and_con += 1
          end

          if pos.stance > 0
            inc_yr_side += inc_points.where('points.is_pro=1').count
            inc_other_side += inc_points.where('points.is_pro=0').count
          elsif pos.stance < 0
            inc_yr_side += inc_points.where('points.is_pro=0').count
            inc_other_side += inc_points.where('points.is_pro=1').count
          end
        else
          neither += 1 
        end
      end

      printf("%i\t%.2f\t%.2f\t%i\t%i\t%.2f\n",
          year, 
          pro_and_con+not_pro_and_con > 0 ? pro_and_con.to_f / (pro_and_con+not_pro_and_con) : -1.0, #inclusions per point
          pro_and_con+not_pro_and_con > 0 ? pro_and_con.to_f / (pro_and_con+not_pro_and_con) : -1.0, #inclusions per position
          inc_yr_side, #inclusions per point
          inc_other_side, #inclusions per position        
          pro_and_con+not_pro_and_con > 0 ? conviction / (pro_and_con+not_pro_and_con) : -1.0
      )
    end

  end

  task :normative_inclusion_by_proposal => :environment do
    years = [2010,2011,2012]
    puts "Normative metrics"
    puts "Year\tProposal\tIncluded pro & con\tIncluded point by opposition\tIncluded for your side\tIncluded for other side\tConviction"
    
    puts "Year\tProposal\tIncluded pro & con\tConviction"

    years.each do |year|

      Proposal.where(:account_id => 1).tagged_with(["#{year}", 'state'], :all => true).each do |prop|

        positions = prop.positions.published.joins(:user).where('users.roles_mask=0')
                
        pro_and_con = 0
        not_pro_and_con = 0
        neither = 0
        inc_yr_side = 0
        inc_other_side = 0

        THRESH = 1

        #if positions.count < 100
        #  next
        #end

        contentiousness = 0.0

        positions.each do |pos|
          if pos.inclusions.count >= THRESH
            contentiousness += pos.stance.abs

            inc_points = pos.inclusions.joins(:point)
            if inc_points.where('points.is_pro=1').count > 0 && inc_points.where('points.is_pro=0').count > 0
              pro_and_con += 1
            else  
              not_pro_and_con += 1
            end

            if pos.stance > 0
              inc_yr_side += inc_points.where('points.is_pro=1').count
              inc_other_side += inc_points.where('points.is_pro=0').count
            elsif pos.stance < 0
              inc_yr_side += inc_points.where('points.is_pro=0').count
              inc_other_side += inc_points.where('points.is_pro=1').count
            end
          else
            neither += 1 
          end
        end

        # printf("%i\t%i\t%.2f\t%.2f\t%i\t%i\t%.2f\n",
        #     year, 
        #     prop.designator,
        #     pro_and_con.to_f / (pro_and_con+not_pro_and_con), #inclusions per point
        #     pro_and_con.to_f / (pro_and_con+not_pro_and_con), #inclusions per position
        #     inc_yr_side, #inclusions per point
        #     inc_other_side, #inclusions per position  
        #     contentiousness / (pro_and_con+not_pro_and_con)        
        # )

        printf("%i\t%i\t%s\t%.2f\t%.2f\n",
            year, 
            prop.designator,
            prop.short_name,
            pro_and_con.to_f / (pro_and_con+not_pro_and_con), #inclusions per point
            contentiousness / (pro_and_con+not_pro_and_con)        
        )        
      end
    end

  end


  task :fact_checking => :environment do 
    puts "Fact-checking metrics"


    impacts = []
    [0,1,2].each do |verdict|
      puts "For points with an overall " + verdict.to_s + " verdict"
      col = :overall_verdict
      #col = :max_verdict
      assessments = Assessable::Assessment.where(col => verdict)

      inclusions = { :before => 0, :after => 0 } 
      views = { :before => 0, :after => 0 }

      normalized_impact = 0
      cnt = 0

      assessments.each do |ass|
        pivot = ass.updated_at
        point = ass.root_object

        #next if ass.claims.count > 1
        #next if point.point_listings.where('created_at > "' + pivot.to_s + '"').count < 10


        population_before = point.proposal.inclusions.where('created_at < "' + pivot.to_s + '"').count.to_f / point.proposal.point_listings.where('created_at < "' + pivot.to_s + '"').count
        population_after = point.proposal.inclusions.where('created_at > "' + pivot.to_s + '"').count.to_f / point.proposal.point_listings.where('created_at > "' + pivot.to_s + '"').count
        population_after = population_after.infinite? ? 1.0 : population_after

        point_before = point.inclusions.where('created_at < "' + pivot.to_s + '"').count.to_f / point.point_listings.where('created_at < "' + pivot.to_s + '"').count
        point_after = point.inclusions.where('created_at > "' + pivot.to_s + '"').count.to_f / point.point_listings.where('created_at > "' + pivot.to_s + '"').count
        point_after = point_after.infinite? ? 1.0 : point_after

        next if point_after.nan?

        normalized_impact += (point_before > 0 ? point_after / point_before : 0) - (population_before > 0 ? population_after / population_before : 0)
        inclusions[:before] += point.inclusions.where('created_at < "' + pivot.to_s + '"').count
        inclusions[:after] += point.inclusions.where('created_at > "' + pivot.to_s + '"') .count
        views[:before] += point.point_listings.where('created_at < "' + pivot.to_s + '"').count
        views[:after] += point.point_listings.where('created_at > "' + pivot.to_s + '"').count
        cnt += 1

        impacts.push([point, normalized_impact, cnt, point.point_listings.where('created_at > "' + pivot.to_s + '"').count, verdict])

      end

      printf("%s:\tinclusions %i\tviews %i\t%.3f\n", 'Before', inclusions[:before], views[:before], inclusions[:before].to_f / views[:before] )
      printf("%s:\tinclusions %i\tviews %i\t%.3f\n", 'After', inclusions[:after], views[:after], inclusions[:after].to_f / views[:after] )

      printf("Impact:\t%.3f\n", (inclusions[:after].to_f / views[:after]) / (inclusions[:before].to_f / views[:before]) )
      printf("Normalized:\t%.3f\n", normalized_impact / cnt )
      pp cnt


    end

    impacts.sort! {|a,b| a[1] <=> b[1]}

    impacts.each do |i|
      printf("%i\t%i\t%i\t%.3f\t%i\n", i[4], i[0].point_listings.count, i[3], i[1], i[0].id)
    end
  end

  task :fact_checking_discussion => :environment do 
    puts "Fact-checking metrics"


    impacts = []
    proposal_point_map = {}
    Point.where('comment_count > 0').each do |pnt|
      comts = pnt.comments.map {|x| x.created_at}.compact
      if !proposal_point_map.has_key? pnt.proposal.id
        proposal_point_map[pnt.proposal_id] = [comts]
      else
        proposal_point_map[pnt.proposal_id].push comts
      end
    end
    #pp proposal_point_map

    [0,1,2].each do |verdict|
      puts "For points with an overall " + verdict.to_s + " verdict"
      col = :overall_verdict
      #col = :max_verdict
      assessments = Assessable::Assessment.where(col => verdict)

      comments = { :before => 0, :after => 0 } 
      views = { :before => 0, :after => 0 }

      normalized_impact = 0
      cnt = 0


      assessments.each do |ass|
        pivot = ass.updated_at
        point = ass.root_object

        #next if point.comments.count == 0
        #next if ass.claims.count > 1
        #next if point.point_listings.where('created_at > "' + pivot.to_s + '"').count < 10

        comments_before_pivot = comments_after_pivot = 0.0

        proposal_point_map[point.proposal_id].each do |pnt|
          pnt.each do |comment|
            if comment < pivot
              comments_before_pivot += 1
            else  
              comments_after_pivot += 1
            end
          end 
        end

        point_before = point.comments.where('created_at < "' + pivot.to_s + '"').count.to_f / point.point_listings.where('created_at < "' + pivot.to_s + '"').count
        point_after = point.comments.where('created_at > "' + pivot.to_s + '"').count.to_f / point.point_listings.where('created_at > "' + pivot.to_s + '"').count
        point_after = point_after.infinite? ? 1.0 : point_after

        population_before = comments_before_pivot / point.proposal.point_listings.where('created_at < "' + pivot.to_s + '"').count
        population_after = comments_after_pivot / point.proposal.point_listings.where('created_at > "' + pivot.to_s + '"').count
        population_after = population_after.infinite? ? 1.0 : population_after

        
        next if point_after.nan?

        normalized_impact += (point_before > 0 ? point_after / point_before : 0) - (population_before > 0 ? population_after / population_before : 0)
        comments[:before] += point.comments.where('created_at < "' + pivot.to_s + '"').count
        comments[:after] += point.comments.where('created_at > "' + pivot.to_s + '"') .count
        views[:before] += point.point_listings.where('created_at < "' + pivot.to_s + '"').count
        views[:after] += point.point_listings.where('created_at > "' + pivot.to_s + '"').count
        cnt += 1

        impacts.push([point, normalized_impact, cnt, point.point_listings.where('created_at > "' + pivot.to_s + '"').count, verdict])

      end

      printf("%s:\tcomments %i\tviews %i\t%.3f\n", 'Before', comments[:before], views[:before], comments[:before].to_f / views[:before] )
      printf("%s:\tcomments %i\tviews %i\t%.3f\n", 'After', comments[:after], views[:after], comments[:after].to_f / views[:after] )

      printf("Impact:\t%.3f\n", (comments[:after].to_f / views[:after]) / (comments[:before].to_f / views[:before]) )
      printf("Normalized:\t%.3f\n", normalized_impact / cnt )
      pp cnt


    end

    impacts.sort! {|a,b| a[1] <=> b[1]}

    impacts.each do |i|
      printf("%i\t%i\t%i\t%.3f\t%i\n", i[4], i[0].point_listings.count, i[3], i[1], i[0].id)
    end
  end


  task :referer => :environment do 
    puts "User referals"
    year = 2012
    users = User.where(:account_id => 1).where("YEAR(created_at)=#{year} OR YEAR(last_sign_in_at)=#{year}").where('MONTH(created_at)>8')

    domains = {}

    users.each do |user|
      begin
        domain = URI.parse(user.referer).host
        if user.referer.index('aclk')
          domain = 'google.ads.com'
        end
      rescue
        domain = nil
      end


      if !domains.has_key?(domain)
        domains[domain] = {:users => 0, :positions => 0, :points => 0, :inclusions => 0}
      end
      domains[domain][:users] += 1 
      domains[domain][:positions] += user.positions.published.where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8').count
      domains[domain][:points] += user.points.published.where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8').count      
      domains[domain][:inclusions] += user.inclusions.where("YEAR(inclusions.created_at)=#{year}").where('MONTH(inclusions.created_at)>8').joins(:position).where('positions.published = 1').count
      #domains[domain][:comments] += user.comments.where("YEAR(created_at)=#{year}").where('MONTH(created_at)>8').count      
    end

    as_array = []; domains.each {|k,vs| as_array.push([k,vs]) }  

    puts( "Domain\tusers\tpositions\tinclusions\tpoints")
    as_array.sort{|x,y| x[1][:users]<=>y[1][:users]}.each do |domain|
        printf("%s\t%i\t%i\t%i\t%i\n",

        domain[0], 
        domain[1][:users],
        domain[1][:positions],
        domain[1][:inclusions],
        domain[1][:points]
        #domain[:comments]
      )
    end
  end

















end